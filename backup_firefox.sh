#!/bin/bash;

current_dir=$(pwd);

mkdir /tmp/firefox.tmp.dir;

cd /tmp/firefox.tmp.dir;

cp -r ~/.mozilla/ ./;

rm -rf ./**/storage/*;

zip -r firefox_backup.zip /.mozilla;

cd $current_dir;
