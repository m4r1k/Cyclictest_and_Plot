#!/bin/bash

# https://rpmfind.net/linux/rpm2html/search.php?query=gnuplot&submit=Search+...&system=centos&arch=x86_64
yum install -y https://rpmfind.net/linux/centos/7.5.1804/os/x86_64/Packages/gnuplot-4.6.2-3.el7.x86_64.rpm
yum install -y rt-tests
yum install -y kernel-rt-kvm kernel-rt
