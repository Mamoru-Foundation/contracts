#!/usr/bin/env sh

TESTNET_PACKAGE_ID="0x4958a3a96e91380a443d116b84c07b48dba90bce664d9f060f94a8f26f537e62"
TESTNET_COUNTER_ADDRESS="0xaa6752395f8740b1ee6cee50d43cf3a1b703c06ade0a7f730032e8d20e7c5861"

sui client call --gas-budget 10000000 \
  --package ${TESTNET_PACKAGE_ID} \
  --module counter \
  --function set_value \
  --args ${TESTNET_COUNTER_ADDRESS} 300
