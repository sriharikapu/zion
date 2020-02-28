// Copyright (c) 2016-2020 Clearmatics Technologies Ltd
// SPDX-License-Identifier: LGPL-3.0+
pragma solidity ^0.5.12;

import "../libraries/SolidityUtils.sol";
import "../libraries/RLP.sol";

/*
    EventVerifier

    This contract is the basic global EventVerifier interface that all specific event verifiers must inherit from.

    It supplies a function `retrieveLog` that will output the relevant log for a specified event signature from the
    provided receipts. Each specific verifier that inherits this contract must hold knowledge of the event signature it
    intends to consume which will be passed to the retrieval function for log separation.
*/

contract EventVerifier {
    /*
        retrieveLogs
        param: _eventSignature (bytes32) Hash representing the event signature of the event type to be consumed
        param: _contractEmittedAddress (bytes20) Address of the contract expected to have emitted the event
        param: _rlpReceipt (bytes) RLP-encoded receipt containing the relevant logs

        returns: log (RLP.RLPItem[]) Decoded log object in the form [ contractAddress, topics, data ]

        This decodes an RLP-encoded receipt and trawls through the logs to find the event that matches the event
        signature required and checks if the event was emitted from the correct source. If no log could be found with
        the relevant signature or emitted from the expected source the execution fails with an assert.

        If a log is not found, an `assert(false)` consumes all the gas and fails the transaction in order to incentivise
        submission of proper data.
    */

    function retrieveLogs(bytes32 _eventSignature, bytes20 _contractEmittedAddress, bytes memory _rlpReceipt)
    internal pure returns (RLP.RLPItem[] memory)
    {
        /*  Decode the receipt into it's consituents and grab the logs with it's known position in the receipt
            object and proceed to decode the logs also.
        */
        RLP.RLPItem[] memory receipt = RLP.toList(RLP.toRLPItem(_rlpReceipt));
        RLP.RLPItem[] memory logs = RLP.toList(receipt[3]);

        /*  The receipts could contain multiple event logs if a single transaction emitted multiple events. We need to
            separate them and locate the relevant event by signature.
        */

        RLP.RLPItem[] memory matchedLogs = new RLP.RLPItem[](logs.length);
        uint nMatched = 0;
        for (uint i = 0; i < logs.length; i++) {
            RLP.RLPItem[] memory log = RLP.toList(logs[i]);
            RLP.RLPItem[] memory topics = RLP.toList(log[1]);

            bytes32 containedEventSignature = RLP.toBytes32(topics[0]);
            if (containedEventSignature == _eventSignature) {
                // If event signature is found, check the contract address it was emitted from
                bytes20 b20_emissionSource = SolUtils.BytesToBytes20(RLP.toData(log[0]), 0);
                if( b20_emissionSource == _contractEmittedAddress) {
                    matchedLogs[nMatched] = logs[i];
                    nMatched++;
                }
            }
        }
        return matchedLogs;
    }

}