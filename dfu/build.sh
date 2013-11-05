#!/bin/sh
# Builds a copy of dfu-programmer suitable for bundling within the Platypus-built firmware app

BUILD_DIR="`dirname \"$0\"`"
if [ "$BUILD_DIR" == "." ]
then
	BUILD_DIR="`pwd`"
fi

cd src

cd libusbx-1.0.16
./configure --prefix="$BUILD_DIR" CFLAGS="-m32 -mmacosx-version-min=10.5"
make
make install
make clean
cd ..
cd libusb-compat-0.1.5
./configure --prefix="$BUILD_DIR" LIBUSB_1_0_CFLAGS=-I"$BUILD_DIR/include/libusb-1.0" LIBUSB_1_0_LIBS=-L"$BUILD_DIR/lib -lusb-1.0" CFLAGS="-m32 -mmacosx-version-min=10.5"
make
make install
make clean
cd ..
cd dfu-programmer
./configure --prefix="$BUILD_DIR" LIBUSB_1_0_CFLAGS=-I"$BUILD_DIR"/include/libusb-1.0 LIBUSB_1_0_LIBS=-L"$BUILD_DIR/lib -lusb-1.0" CFLAGS="-m32 -mmacosx-version-min=10.5" LDFLAGS="-L$BUILD_DIR/lib/"
make
make install
make clean
cd ..

cd ..
