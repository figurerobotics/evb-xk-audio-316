#!/usr/bin/env python
# Copyright 2016-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import xmostest

def do_frontend_test(channel_count, testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'test_pdm_interface/bin/CH{ch}/test_pdm_interface_CH{ch}.xe'.format(ch=channel_count)

    tester = xmostest.ComparisonTester(open('pdm_interface.expect'),
                                       'lib_mic_array',
                                       'lib_mic_array_frontend_tests',
                                       'frontend_test_%s'%testlevel,
                                       {'channel_count':channel_count})

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simargs=[],
                              tester = tester)

def runtest():
    do_frontend_test(4, "smoke")
    do_frontend_test(8, "smoke")
