//
// Copyright 2011-2012,2014 Ettus Research LLC
// Copyright 2018 Ettus Research, a National Instruments Company
//
// SPDX-License-Identifier: GPL-3.0-or-later
//

#include <uhd/exception.hpp>
#include <uhd/usrp/multi_usrp.hpp>
#include <uhd/utils/safe_main.hpp>
#include <uhd/utils/static.hpp>
#include <uhd/utils/thread.hpp>
#include <stdint.h>
#include <boost/algorithm/string.hpp>
#include <boost/format.hpp>
#include <boost/math/special_functions/round.hpp>
#include <boost/program_options.hpp>
#include <chrono>
#include <complex>
#include <csignal>
#include <iostream>
#include <fstream>
#include <thread>

namespace po = boost::program_options;

/***********************************************************************
 * Signal handlers
 **********************************************************************/
static bool stop_signal_called = false;
void sig_int_handler(int)
{
    stop_signal_called = true;
}

void TX_time()
{   
    time_t now = time(0);
    char* date_time = ctime(&now);
    std::cout << "Packet sent at :" << std::endl;
    std::cout << date_time << std::endl;

}

// read_from_files
std::vector<std::complex<float> > read_from_file(const std::string &file, size_t samps_per_buff)
{ 
    std::vector<std::complex<float> > buff(samps_per_buff);
    std::ifstream infile(file.c_str(), std::ifstream::binary);
   
    while(not infile.eof() and not stop_signal_called){
        infile.read((char*)&buff.front(), buff.size()*sizeof(std::complex<float>));
    }
    std::cout<<"buff size: "<<buff.size()<<std::endl;
    infile.close();
    return buff;
}

// send from buffers
void send_from_buffer(uhd::tx_streamer::sptr tx_stream, std::vector<std::complex<float>*> buffs, size_t buff_size)
{   uhd::tx_metadata_t md;
    md.start_of_burst = false;
    md.end_of_burst = false;

    TX_time();
    // send out packet
    const size_t samples_sent = tx_stream->send(buffs, buff_size, md);
    std::cout << "Buff2[250000] is" << samples_sent << std::endl;

}

/***********************************************************************
 * Main function
 **********************************************************************/
int UHD_SAFE_MAIN(int argc, char* argv[])
{
    // variables to be set by po
    std::string args, file1, file2, ant, subdev, ref, otw, channel_list;
    size_t spb;
    double rate, freq, gain, bw, lo_offset, delay;
    double gain_rf, freq_rf;

    // setup the program options
    po::options_description desc("Allowed options");
    // clang-format off
    desc.add_options()
        ("help", "help message")
        ("args", po::value<std::string>(&args)->default_value("type=x300"), "single uhd device address args")
		("file1", po::value<std::string>(&file1)->default_value("tx_data1"), "name of the file to read binary samples from")
        ("file2", po::value<std::string>(&file2)->default_value("tx_data2"), "name of the file to read binary samples from")
        ("spb", po::value<size_t>(&spb)->default_value(1e6), "samples per buffer, 0 for default")
        ("rate", po::value<double>(&rate)->default_value(1e6), "rate of outgoing samples")
        ("freq", po::value<double>(&freq)->default_value(3e9-125e3), "RF center frequency in Hz")
        ("freq-rf", po::value<double>(&freq_rf)->default_value(3e9+125e3), "RF center frequency in Hz")
        ("lo-offset", po::value<double>(&lo_offset)->default_value(0.0),
            "Offset for frontend LO in Hz (optional)")
        ("delay", po::value<double>(&delay)->default_value(4), "specify the delay between repeated samples")
        ("gain", po::value<double>(&gain)->default_value(0), "gain for the RF chain")
        ("gain-rf", po::value<double>(&gain_rf)->default_value(0), "gain for the RF chain")
        ("ant", po::value<std::string>(&ant)->default_value("TX/RX"), "antenna selection")
        ("subdev", po::value<std::string>(&subdev)->default_value("A:0"), "subdevice specification")
        ("bw", po::value<double>(&bw)->default_value(10e6), "analog frontend filter bandwidth in Hz")
        ("ref", po::value<std::string>(&ref)->default_value("internal"), "clock reference (internal, external, mimo, gpsdo)")
        ("otw", po::value<std::string>(&otw)->default_value("sc16"), "specify the over-the-wire sample mode")
        ("channels", po::value<std::string>(&channel_list)->default_value("0"), "which channels to use (specify \"0\", \"1\", \"0,1\", etc)")
        ("int-n", "tune USRP with integer-N tuning")
    ;
	// repeat transmission
	bool repeat = 1 > 0;
	   
    // clang-format on
    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    po::notify(vm);

    // print the help message
    if (vm.count("help")) {
        std::cout << boost::format("UHD TX Waveforms %s") % desc << std::endl;
        return ~0;
    }

    // create a usrp device
    std::cout << std::endl;
    std::cout << boost::format("Creating the usrp device with: %s...") % args
              << std::endl;
    uhd::usrp::multi_usrp::sptr usrp = uhd::usrp::multi_usrp::make(args);

    // always select the subdevice first, the channel mapping affects the other settings
    if (vm.count("subdev"))
        usrp->set_tx_subdev_spec(subdev);

    // detect which channels to use
    std::vector<std::string> channel_strings;
    std::vector<size_t> channel_nums;
    boost::split(channel_strings, channel_list, boost::is_any_of("\"',"));
    for (size_t ch = 0; ch < channel_strings.size(); ch++) {
        size_t chan = std::stoi(channel_strings[ch]);
        if (chan >= usrp->get_tx_num_channels())
            throw std::runtime_error("Invalid channel(s) specified.");
        else
            channel_nums.push_back(std::stoi(channel_strings[ch]));
    }

    // Lock mboard clocks
    if (vm.count("ref")) {
        usrp->set_clock_source(ref);
        std::cout << "Clock Source " << usrp->get_clock_source(0) << std::endl;
    }

    std::cout << boost::format("Using Device: %s") % usrp->get_pp_string() << std::endl;

    // set the sample rate
    if (not vm.count("rate")) {
        std::cerr << "Please specify the sample rate with --rate" << std::endl;
        return ~0;
    }
    std::cout << boost::format("Setting TX Rate: %f Msps...") % (rate / 1e6) << std::endl;
    usrp->set_tx_rate(rate);
    std::cout << boost::format("Actual TX Rate: %f Msps...") % (usrp->get_tx_rate() / 1e6)
              << std::endl
              << std::endl;

    // set the center frequency
    if (not vm.count("freq")) {
        std::cerr << "Please specify the center frequency with --freq" << std::endl;
        return ~0;
    }

    size_t index = 0;

    for (size_t ch = 0; ch < channel_nums.size(); ch++) {
        freq = (ch == 0) ? freq : freq_rf;
        std::cout << boost::format("Setting TX Freq: %f MHz...") % (freq / 1e6)
                  << std::endl;
        std::cout << boost::format("Setting TX LO Offset: %f MHz...") % (lo_offset / 1e6)
                  << std::endl;
        uhd::tune_request_t tune_request(freq, lo_offset);
        if (vm.count("int-n"))
            tune_request.args = uhd::device_addr_t("mode_n=integer");
        usrp->set_tx_freq(tune_request, channel_nums[ch]);
        std::cout << boost::format("Actual TX Freq: %f MHz...")
                         % (usrp->get_tx_freq(channel_nums[ch]) / 1e6)
                  << std::endl
                  << std::endl;

        // set the rf gain
        if (vm.count("power")) {
            if (!usrp->has_tx_power_reference(ch)) {
                std::cout << "ERROR: USRP does not have a reference power API on channel "
                          << ch << "!" << std::endl;
                return EXIT_FAILURE;
            }
            if (vm.count("gain")) {
                std::cout << "WARNING: If you specify both --power and --gain, "
                             " the latter will be ignored."
                          << std::endl;
            }
        } else if (vm.count("gain")) {
            gain = (ch == 0) ? gain : gain_rf;
            std::cout << boost::format("Setting TX Gain: %f dB...") % gain << std::endl;
            usrp->set_tx_gain(gain, channel_nums[ch]);
            std::cout << boost::format("Actual TX Gain: %f dB...")
                             % usrp->get_tx_gain(channel_nums[ch])
                      << std::endl
                      << std::endl;
        }

        // set the analog frontend filter bandwidth
        if (vm.count("bw")) {
            std::cout << boost::format("Setting TX Bandwidth: %f MHz...") % bw
                      << std::endl;
            usrp->set_tx_bandwidth(bw, channel_nums[ch]);
            std::cout << boost::format("Actual TX Bandwidth: %f MHz...")
                             % usrp->get_tx_bandwidth(channel_nums[ch])
                      << std::endl
                      << std::endl;
        }

        // set the antenna
        if (vm.count("ant"))
            usrp->set_tx_antenna(ant, channel_nums[ch]);
    }

    std::this_thread::sleep_for(std::chrono::seconds(1)); // allow for some setup time

    // create a transmit streamer
    // linearly map channels (index0 = channel0, index1 = channel1, ...)
    uhd::stream_args_t stream_args("fc32", otw);
    stream_args.channels             = channel_nums;
    uhd::tx_streamer::sptr tx_stream = usrp->get_tx_stream(stream_args);

      // Check Ref and LO Lock detect
    std::vector<std::string> sensor_names;
    const size_t tx_sensor_chan = channel_nums.empty() ? 0 : channel_nums[0];
    sensor_names                = usrp->get_tx_sensor_names(tx_sensor_chan);
    if (std::find(sensor_names.begin(), sensor_names.end(), "lo_locked")
        != sensor_names.end()) {
        uhd::sensor_value_t lo_locked = usrp->get_tx_sensor("lo_locked", tx_sensor_chan);
        std::cout << boost::format("Checking TX: %s ...") % lo_locked.to_pp_string()
                  << std::endl;
        UHD_ASSERT_THROW(lo_locked.to_bool());
    }
    const size_t mboard_sensor_idx = 0;
    sensor_names                   = usrp->get_mboard_sensor_names(mboard_sensor_idx);
    if ((ref == "mimo")
        and (std::find(sensor_names.begin(), sensor_names.end(), "mimo_locked")
                != sensor_names.end())) {
        uhd::sensor_value_t mimo_locked =
            usrp->get_mboard_sensor("mimo_locked", mboard_sensor_idx);
        std::cout << boost::format("Checking TX: %s ...") % mimo_locked.to_pp_string()
                  << std::endl;
        UHD_ASSERT_THROW(mimo_locked.to_bool());
    }
    if ((ref == "external")
        and (std::find(sensor_names.begin(), sensor_names.end(), "ref_locked")
                != sensor_names.end())) {
        uhd::sensor_value_t ref_locked =
            usrp->get_mboard_sensor("ref_locked", mboard_sensor_idx);
        std::cout << boost::format("Checking TX: %s ...") % ref_locked.to_pp_string()
                  << std::endl;
        UHD_ASSERT_THROW(ref_locked.to_bool());
    }

    std::signal(SIGINT, &sig_int_handler);
    std::cout << "Press Ctrl + C to stop streaming..." << std::endl;
	
    // read from file
    std::vector<std::complex<float> > buff1  = read_from_file(file1, spb);
    std::vector<std::complex<float> > buff2  = read_from_file(file2, spb);
    std::cout << "Buff1[250000] is" << buff1[249999] << std::endl;
    std::cout << "Buff2[250000] is" << buff2[249999] << std::endl;

    std::vector<std::complex<float>*> buffs = {&buff1.front(),&buff2.front()};
   
    // send from buffer
   do { send_from_buffer(tx_stream, buffs, buff1.size());
     
        if (repeat and delay > 0.0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(int64_t(delay * 1000)));
        }
    } while (repeat and not stop_signal_called);

    // finished
    std::cout << std::endl << "Done!" << std::endl << std::endl;

    return EXIT_SUCCESS;
}