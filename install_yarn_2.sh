#!/bin/bash

## INSTALL YARN 2 + PNPM MODE 
## YARN 2 CONFIGURES PER PACKAGE

yarn set version berry

echo "nodeLinker: node-modules" > .yarnrc.yml
