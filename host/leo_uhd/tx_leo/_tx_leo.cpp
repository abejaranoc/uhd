//
// Copyright 2011-2012,2014 Ettus Research LLC
// Copyright 2018 Ettus Research, a National Instruments Company
//
// SPDX-License-Identifier: GPL-3.0-or-later
//

#include <uhd/types/tune_request.hpp>
#include <uhd/usrp/multi_usrp.hpp>
#include <uhd/utils/safe_main.hpp>
#include <uhd/utils/thread.hpp>
#include <boost/format.hpp>
#include <boost/program_options.hpp>
#include <chrono>
#include <complex>
#include <csignal>
#include <fstream>
#include <iostream>
#include <thread>

namespace po = boost::program_options;

static bool stop_signal_called = false;
void sig_int_handler(int)
{
    stop_signal_called = true;
}

// record the time of the laptop
void TX_time()
{   
    time_t now = time(0);
    char* date_time = ctime(&now);
    std::cout << "Packet sended at :" << std::endl;
    std::cout << date_time << std::endl;

}

std::vector<std::complex<float> > read_from_file(const std::string &file, size_t samps_per_buff)
{ 
    std::vector<std::complex<float> > buff(samps_per_buff);
    std::ifstream infile(file.c_str(), std::ifstream::binary);
   
    while(not infile.eof() and not stop_signal_called){
        infile.read((char*)&buff.front(), buff.size()*sizeof(std::complex<float>));
    }
    std::cout<<"buff size: "<<buff.size()<<std::endl;
    //size_t num_tx_samps = size_t(infile.gcount() / sizeof(std::complex<float>));
    //std::cout << "Packet length is : " << num_tx_samps << std::endl;
    infile.close();
    return buff;
}

void send_from_buffer(uhd::tx_streamer::sptr tx_stream, std::vector<std::complex<float> > buff)
{   uhd::tx_metadata_t md;
    md.start_of_burst = false;
    md.end_of_burst = false;

    TX_time();
    // send out packet
    const size_t samples_sent = tx_stream->send(&buff.front(), buff.size(), md);
}


// read data from files

int UHD_SAFE_MAIN(int argc, char* argv[])
{
    // variables to be set by po
    std::string args, file, type, ant, subdev, ref, wirefmt, channel;
    size_t spb;
    double rate, freq, gain, bw, delay, lo_offset;

    // setup the program options
    po::options_description desc("Allowed options");
    // clang-format off
    desc.add_options()
        ("help", "help message")
        ("args", po::value<std::string>(&args)->default_value("addr=192.168.10.2"), "multi uhd device address args")
        ("file", po::value<std::string>(&file)->default_value("tx_data1"), "name of the file to read binary samples from")
        ("type", po::value<std::string>(&type)->default_value("float"), "sample type: double, float, or short")
        ("spb", po::value<size_t>(&spb)->default_value(1e6), "samples per buffer")
        ("rate", po::value<double>(&rate)-> default_value(1e6), "rate of outgoing samples")
        ("freq", po::value<double>(&freq)-> default_value(3e9) , "RF center frequency in Hz")
        ("lo-offset", po::value<double>(&lo_offset)->default_value(0.0),
            "Offset for frontend LO in Hz (optional)")
        ("gain", po::value<double>(&gain)-> default_value(10), "gain for the RF chain")
        ("ant", po::value<std::string>(&ant)-> default_value("TX/RX"),"antenna selection")
        ("subdev", po::value<std::string>(&subdev)->default_value("A:0"), "subdevice specification")
        ("bw", po::value<double>(&bw)-> default_value(10e6), "analog frontend filter bandwidth in Hz")
        ("ref", po::value<std::string>(&ref)->default_value("internal"), "reference source (internal, external, mimo)")
        ("wirefmt", po::value<std::string>(&wirefmt)->default_value("sc16"), "wire format (sc8 or sc16)")
        ("delay", po::value<double>(&delay)->default_value(9.0), "specify a delay between repeated transmission of file (in seconds)")
        ("channel", po::value<std::string>(&channel)->default_value("0"), "which channel to use")
        //("repeat", "repeatedly transmit file")
        ("int-n", "tune USRP with integer-n tuning")
    ;
    // clang-format on
    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    po::notify(vm);

    // print the help message
    if (vm.count("help")) {
        std::cout << boost::format("UHD TX samples from file %s") % desc << std::endl;
        return ~0;
    }

    bool repeat = 1 > 0;

    // create a usrp device
    std::cout << std::endl;
    std::cout << boost::format("Creating the usrp device with: %s...") % args
              << std::endl;
    uhd::usrp::multi_usrp::sptr usrp = uhd::usrp::multi_usrp::make(args);

    // Lock mboard clocks
    if (vm.count("ref")) {
        usrp->set_clock_source(ref);
    }

    // always select the subdevice first, the channel mapping affects the other settings
    if (vm.count("subdev"))
        usrp->set_tx_subdev_spec(subdev);

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
    std::cout << boost::format("Setting TX Freq: %f MHz...") % (freq / 1e6) << std::endl;
    std::cout << boost::format("Setting TX LO Offset: %f MHz...") % (lo_offset / 1e6)
              << std::endl;
    uhd::tune_request_t tune_request;
    tune_request = uhd::tune_request_t(freq, lo_offset);
    if (vm.count("int-n"))
        tune_request.args = uhd::device_addr_t("mode_n=integer");
    usrp->set_tx_freq(tune_request);
    std::cout << boost::format("Actual TX Freq: %f MHz...") % (usrp->get_tx_freq() / 1e6)
              << std::endl
              << std::endl;

    // set the rf gain
    if (vm.count("gain")) {
        std::cout << boost::format("Setting TX Gain: %f dB...") % gain << std::endl;
        usrp->set_tx_gain(gain);
        std::cout << boost::format("Actual TX Gain: %f dB...") % usrp->get_tx_gain()
                  << std::endl
                  << std::endl;
    }

    // set the analog frontend filter bandwidth
    if (vm.count("bw")) {
        std::cout << boost::format("Setting TX Bandwidth: %f MHz...") % (bw / 1e6)
                  << std::endl;
        usrp->set_tx_bandwidth(bw);
        std::cout << boost::format("Actual TX Bandwidth: %f MHz...")
                         % (usrp->get_tx_bandwidth() / 1e6)
                  << std::endl
                  << std::endl;
    }

    // set the antenna
    if (vm.count("ant"))
        usrp->set_tx_antenna(ant);

    // allow for some setup time:
    std::this_thread::sleep_for(std::chrono::seconds(1));

    // Check Ref and LO Lock detect
    std::vector<std::string> sensor_names;
    sensor_names = usrp->get_tx_sensor_names(0);
    if (std::find(sensor_names.begin(), sensor_names.end(), "lo_locked")
        != sensor_names.end()) {
        uhd::sensor_value_t lo_locked = usrp->get_tx_sensor("lo_locked", 0);
        std::cout << boost::format("Checking TX: %s ...") % lo_locked.to_pp_string()
                  << std::endl;
        UHD_ASSERT_THROW(lo_locked.to_bool());
    }
    sensor_names = usrp->get_mboard_sensor_names(0);
    if ((ref == "mimo")
        and (std::find(sensor_names.begin(), sensor_names.end(), "mimo_locked")
             != sensor_names.end())) {
        uhd::sensor_value_t mimo_locked = usrp->get_mboard_sensor("mimo_locked", 0);
        std::cout << boost::format("Checking TX: %s ...") % mimo_locked.to_pp_string()
                  << std::endl;
        UHD_ASSERT_THROW(mimo_locked.to_bool());
    }
    if ((ref == "external")
        and (std::find(sensor_names.begin(), sensor_names.end(), "ref_locked")
             != sensor_names.end())) {
        uhd::sensor_value_t ref_locked = usrp->get_mboard_sensor("ref_locked", 0);
        std::cout << boost::format("Checking TX: %s ...") % ref_locked.to_pp_string()
                  << std::endl;
        UHD_ASSERT_THROW(ref_locked.to_bool());
    }

    // set sigint if user wants to receive
    if (repeat) {
        std::signal(SIGINT, &sig_int_handler);
        std::cout << "Press Ctrl + C to stop streaming..." << std::endl;
    }

    // create a transmit streamer
    std::string cpu_format;
    std::vector<size_t> channel_nums;
    if (type == "double")
        cpu_format = "fc64";
    else if (type == "float")
        cpu_format = "fc32";
    else if (type == "short")
        cpu_format = "sc16";
    uhd::stream_args_t stream_args(cpu_format, wirefmt);
    channel_nums.push_back(boost::lexical_cast<size_t>(channel));
    stream_args.channels             = channel_nums;
    uhd::tx_streamer::sptr tx_stream = usrp->get_tx_stream(stream_args);

    // read from file
    std::vector<std::complex<float> > buff  = read_from_file(file, spb);
    std::cout << "Buff[25000] is" << buff[25000] << std::endl;
   

    // send from buffer
    do {  send_from_buffer(tx_stream, buff);
          //send_from_file<std::complex<short>>(tx_stream, file, spb);
     
        if (repeat and delay > 0.0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(int64_t(delay * 1000)));
        }
    } while (repeat and not stop_signal_called);

    // finished
    std::cout << std::endl << "Done!" << std::endl << std::endl;

    return EXIT_SUCCESS;
}
