# xiaomi_firmware

Cool script for generating vendor/firmware/${device} folder from the recovery rom zip

## Usage
- Clone this repo inside rom source rootdir
- Clone [the-muppets/proprietary_vendor_firmware](https://gitlab.com/the-muppets/proprietary_vendor_firmware/-/tree/master) master branch into vendor/firmware
- Go into xiaomi_firmware folder
- Download the recovery zip
- Run this command:
```bash
./xiaomi-firmware.sh --zip recovery_zip --device device_codename
```
- Check if vendor/firmware/${device} exist
- Enjoy :D 

## ToDo
- Make the script more generic
- ...

## Credits
- [the-muppets/proprietary_vendor_firmware](https://gitlab.com/the-muppets/proprietary_vendor_firmware/-/tree/master)
- [tobyxdd/android-ota-payload-extractor](https://github.com/tobyxdd/android-ota-payload-extractor)

```
# Copyright (C) 2023 Giovanni Ricca
# SPDX-License-Identifier: GPL-3.0-or-later
```
