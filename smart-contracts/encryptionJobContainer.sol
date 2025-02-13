// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

contract EncryptionJobContainer {
    struct VerificationParameters {
        uint256[] workerModel; // store weights of the model
        address workerAddress;
    }
    mapping(address => string) addressToPublicKey; // address of a worker to its public key
    mapping(address => bytes32) addressToHashModel; // address of a worker to the encrypted model it sends (32 bits model)
    // address of a worker to the parameters used to verify the model and proof it was computed by the worker
    mapping(address => VerificationParameters) addressToVerificationParameters;

    // for each model, record how many times we have seen it. In solidity we can't use a dynamic array as a key
    // for a mapping, so we use hash of the model as a key
    mapping(bytes32 => uint256) modelToNSameModels;
    // uint256[] models; // keep track of each different model we have seen (models are stored in clear)
    uint256[][] models; // keep track of each different model we have seen (models are stored in clear)
    uint256 nModels = 0; // number of different models we have seen

    address[] receivedModelsAddresses; // each time a worker sends a model, it's address is added to this array
    // each time a worker sends its verification parameters it's address is added to this arra
    address[] receivedVerificationParametersAddresses;

    uint256 currentModel = 134;
    uint256 batchIndex = 12;
    uint256 nWorkers = 10;
    //uint256 thresholdForBestModel = nWorkers / 2; // number of equal models needed to be considered as the best one.
    uint256 thresholdForBestModel = 2; // number of equal models needed to be considered as the best one.
    //uint256 thresholdMaxNumberReceivedModels = nWorkers; // maximum number of models we can receive before we compute the best model
    uint256 thresholdMaxNumberReceivedModels = 3; // maximum number of models we can receive before we compute the best model
    uint256 model_length = 30000; // length of the model
    //uint256 model_length = 10000; // length of the model
    //uint256 model_length = 2000; // length of the model
    uint256[] newModel; // the weight of the new model
    bool modelIsReady = false;
    bool canReceiveNewModel = true;

    //This is a "ugly" solutions, to still reset the smart contract, even if we don't actually store models on it
    uint256 resetCounter = 0;

    modifier onlyReceivedModelsAddresses(address workerAddress) {
        // modified that check if a worker address is inside receivedModelsAddresses
        bool workerHasSendModel = false;
        for (uint256 i = 0; i < receivedModelsAddresses.length; i++) {
            if (receivedModelsAddresses[i] == workerAddress) {
                workerHasSendModel = true;
            }
        }
        require(
            workerHasSendModel,
            "The worker didn't send a model during training phase, parameters refused"
        );
        _;
    }

    modifier modelOnlySendOnce(address workerAddress) {
        // modified that check if a worker address is inside receivedModelsAddresses
        bool workerHasSendModel = false;
        for (uint256 i = 0; i < receivedModelsAddresses.length; i++) {
            if (receivedModelsAddresses[i] == workerAddress) {
                workerHasSendModel = true;
            }
        }
        require(!workerHasSendModel, "The worker already sent a model");
        _;
    }

    function getModelAndBatchIndex() public view returns (uint256, uint256) {
        return (currentModel, batchIndex);
    }

    /// @notice tell weather a worker can send its verification parameters or not
    /// @param workerAddress the address of the worker
    /// @return true if the worker can send its verification parameters, false otherwise
    function canSendVerificationParameters(address workerAddress)
        public
        view
        returns (bool)
    {
        // check if the workerAddress did send a model during learning phase
        bool workerHasSendModel = false;
        for (uint256 i = 0; i < receivedModelsAddresses.length; i++) {
            if (receivedModelsAddresses[i] == workerAddress) {
                workerHasSendModel = true;
            }
        }
        return !canReceiveNewModel && workerHasSendModel;
    }

    /// @notice send a new encrypted model to the jobContainer
    /// @notice each address can send only one model
    /// @notice also reset the learn task if previous learning is done.
    /// @param workerAddress the address of the worker sending the model
    /// @param modelHash the hashed model (xored with worker's public key) sent by the worker
    /// @return true if the model was added to the jobContainer, false otherwise
    function addNewEncryptedModel(uint160 workerAddress, bytes32 modelHash)
        public
        returns (bool)
    {
        // if (getModelIsready()) {
        // TODO Modified to handle case where we don't actually store models on the smart contract
        if (resetCounter > thresholdMaxNumberReceivedModels) {
            resetLearnTask();
        }
        // if we already received the maximum number of models, we don't accept new ones
        if (!canReceiveNewModel) {
            return false;
        }
        address _workerAddress = address(workerAddress); // equivalent to receiving the worker address (checked on remix)
        receivedModelsAddresses.push(_workerAddress);
        addressToHashModel[_workerAddress] = modelHash; // TODO uncomment
        // if the number of received model is equal to the thresholdMaxNumberReceivedModels, we stop receiving
        // new models
        if (
            receivedModelsAddresses.length == thresholdMaxNumberReceivedModels
        ) {
            canReceiveNewModel = false;
        }
        return true;
    }

    function computeKeccak256(bytes1[32] memory clearModel)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(clearModel));
    }

    /// @notice send a new verification parameters to the jobContainer
    /// @notice each address can send only one verification parameters (if has previously sent a model)
    /// @param array the array containing the verification parameters. By convention, the first element of the array
    /// is the address of worker encoded as uint160. Remaining elements are models' weights
    // function addVerificationParameters(uint256[] memory array)
    //     public
    //     onlyReceivedModelsAddresses(address(uint160(array[0])))
    // {
    //     address _workerAddress = address(uint160(array[0]));
    //     uint256[] memory clearModel = new uint256[](array.length - 1);
    //     for (uint256 i = 1; i < array.length; ++i) {
    //         clearModel[i - 1] = array[i];
    //     }
    //     // check that worker has send a model, that don't receive new model anymore and that model is not ready
    //     if (canSendVerificationParameters(_workerAddress) && !modelIsReady) {
    //         // require that the _workerAddress isn't already in receivedVerificationParametersAddresses
    //         for (
    //             uint256 i = 0;
    //             i < receivedVerificationParametersAddresses.length;
    //             i++
    //         ) {
    //             require(
    //                 receivedVerificationParametersAddresses[i] !=
    //                     _workerAddress,
    //                 "You already sent your verification parameters"
    //             );
    //         }
    //         // if this address didn't already pushed a model, we can add it to receivedVerificationParametersAddresses
    //         receivedVerificationParametersAddresses.push(_workerAddress);
    //         addressToVerificationParameters[
    //             _workerAddress
    //         ] = VerificationParameters(clearModel, _workerAddress);
    //         // We check if hash of clear model + worker's address converted to uint256
    //         // is equal to the hash of the model sent by the worker during leaning phase
    //         // bytes32 modelHash = keccak256(abi.encodePacked(uint8(97), uint8(98), uint8(99)));
    //         uint256[] memory model_with_public_key = new uint256[](
    //             clearModel.length
    //         );
    //         // add uint256(_workerAddress) to each element of clearModel
    //         for (uint256 i = 0; i < clearModel.length; i++) {
    //             model_with_public_key[i] =
    //                 clearModel[i] +
    //                 uint256(_workerAddress);
    //         }
    //         bytes32 modelHash = keccak256(
    //             abi.encodePacked(model_with_public_key)
    //         );
    //         // we get the model sent by the worker during learning phase
    //         bytes32 modelSentByWorker = addressToHashModel[_workerAddress];
    //         // we check if the two are equals
    //         require(
    //             modelHash == modelSentByWorker,
    //             "The model sent by the worker during learning phase is not equal to the model computed by the worker during verification phase"
    //         );
    //         // worker proved is did work to send its model, we can add it to the received clear models
    //         setValueModelToNSameModels(
    //             clearModel,
    //             getValueModelToNSameModels(clearModel) + 1
    //         );
    //         // check if we already registered this model
    //         bool modelAlreadyInModels = false;
    //         uint256 clearModelLen = clearModel.length;
    //         for (uint256 i = 0; i < models.length; i++) {
    //             if (models[i].length != clearModelLen) {
    //                 // in that case, we cannot already have this model in models
    //                 continue;
    //             }
    //             // we check if the two models are equals
    //             bool modelsAreEquals = true;
    //             for (uint256 j = 0; j < clearModelLen; j++) {
    //                 if (models[i][j] != clearModel[j]) {
    //                     modelsAreEquals = false;
    //                 }
    //             }
    //             if (modelsAreEquals) {
    //                 modelAlreadyInModels = true;
    //             }
    //         }
    //         // if decryptedModel not in models, we add it
    //         if (!modelAlreadyInModels) {
    //             models.push(clearModel);
    //             nModels += 1;
    //         }
    //         uint256[] memory _bestModel = checkEnoughSameModel();
    //         if (_bestModel.length != 0) {
    //             // in that case we elected the best model, so we can pay workers that did correct job
    //             modelIsReady = true;
    //             // publish the new model
    //             newModel = _bestModel;
    //             // pay workers
    //             //payCorrectWorkers(_bestModel);
    //         }
    //     } else {
    //         revert("You can't send your verification parameters");
    //     }
    // }
    /// @notice send a new verification parameters to the jobContainer
    /// @notice each address can send only one verification parameters (if has previously sent a model)
    /// @param array the array containing the verification parameters. By convention, the first element of the array
    /// is the address of worker encoded as uint160. Remaining elements are models' weights
    function addVerificationParameters(uint256[] memory array)
        public
        onlyReceivedModelsAddresses(address(uint160(array[0])))
    {
        address _workerAddress = address(uint160(array[0]));
        uint256[] memory clearModel = new uint256[](model_length);
        uint256 received_array_length = array.length - 1;
        //uint256 received_array_length = 1000;
        uint256 n_repetitions = model_length / received_array_length; // array.length should always be 1k
        for (uint256 repetition = 0; repetition < n_repetitions; ++repetition) {
            for (uint256 i = 1; i <= received_array_length; ++i) {
                //clearModel[repetition * received_array_length + (i - 1)] = array[i];
                clearModel[
                    repetition * received_array_length + (i - 1)
                ] = array[1]; // we can ause first element as weights are all of same values
            }
        }
        // check that worker has send a model, that don't receive new model anymore and that model is not ready
        if (canSendVerificationParameters(_workerAddress) && !modelIsReady) {
            // require that the _workerAddress isn't already in receivedVerificationParametersAddresses
            for (
                uint256 i = 0;
                i < receivedVerificationParametersAddresses.length;
                i++
            ) {
                require(
                    receivedVerificationParametersAddresses[i] !=
                        _workerAddress,
                    "You already sent your verification parameters"
                );
            }

            // if this address didn't already pushed a model, we can add it to receivedVerificationParametersAddresses
            receivedVerificationParametersAddresses.push(_workerAddress);
            // TODO we also dont add the model to the receivedVerificationParametersAddresses, as its too expensive
            // addressToVerificationParameters[
            //     _workerAddress
            // ] = VerificationParameters(clearModel, _workerAddress);
            //We check if hash of clear model + worker's address converted to uint256
            //is equal to the hash of the model sent by the worker during leaning phase
            uint256[] memory model_with_public_key = new uint256[](
                clearModel.length
            );
            // add uint256(_workerAddress) to each element of clearModel
            uint256 intWorkerAddress = uint256(_workerAddress);
            for (uint256 i = 0; i < clearModel.length; i++) {
                model_with_public_key[i] = clearModel[i] + intWorkerAddress;
            }
            //bytes32 modelHash = keccak256(abi.encodePacked(uint8(97), uint8(98), uint8(99)));
            bytes32 modelHash = keccak256(
                abi.encodePacked(model_with_public_key)
            );
            // we get the model sent by the worker during learning phase
            bytes32 modelSentByWorker = addressToHashModel[_workerAddress];
            // we check if the two are equals
            require(
                modelHash == modelSentByWorker,
                "The model sent by the worker during learning phase is not equal to the model computed by the worker during verification phase"
            );
            resetCounter += 1;
            if (resetCounter >= thresholdMaxNumberReceivedModels) {
                // model is ready
                modelIsReady = true;
            }
        }

        // --------------------- From here, we can remove the verification phase ---------------------
        // worker proved is did work to send its model, we can add it to the received clear models
        // setValueModelToNSameModels(
        //     clearModel,
        //     getValueModelToNSameModels(clearModel) + 1
        // );
        // // check if we already registered this model
        // bool modelAlreadyInModels = false;
        // uint256 clearModelLen = clearModel.length;
        // for (uint256 i = 0; i < models.length; i++) {
        //     if (models[i].length != clearModelLen) {
        //         // in that case, we cannot already have this model in models
        //         continue;
        //     }
        //     // we check if the two models are equals
        //     bool modelsAreEquals = true;
        //     for (uint256 j = 0; j < clearModelLen; j++) {
        //         if (models[i][j] != clearModel[j]) {
        //             modelsAreEquals = false;
        //         }
        //     }
        //     if (modelsAreEquals) {
        //         modelAlreadyInModels = true;
        //     }
        // }
        // // if decryptedModel not in models, we add it
        // if (!modelAlreadyInModels) {
        //     models.push(clearModel);
        //     nModels += 1;
        // }
        // uint256[] memory _bestModel = checkEnoughSameModel();
        // if (_bestModel.length != 0) {
        //     // in that case we elected the best model, so we can pay workers that did correct job
        //     modelIsReady = true;
        //     // publish the new model
        //     newModel = _bestModel;
        //     // pay workers
        //     //payCorrectWorkers(_bestModel);
        // }
        // } else {
        //     revert("You can't send your verification parameters");
        // }
    }

    function checkEnoughSameModel() private view returns (uint256[] memory) {
        // if one of the model has been seen more than thresholdForBestModel times, we return true
        for (uint256 i = 0; i < models.length; i++) {
            if (
                getValueModelToNSameModels(models[i]) >= thresholdForBestModel
            ) {
                return models[i];
            }
        }
        // return an empty dynamic array
        return new uint256[](0);
    }

    function payCorrectWorkers(bytes32 correctModel) private view {
        require(modelIsReady, "The model is not ready yet");
        for (
            uint256 i = 0;
            i < receivedVerificationParametersAddresses.length;
            i++
        ) {
            address workerAddress = receivedVerificationParametersAddresses[i];
            VerificationParameters
                memory verificationParameters = addressToVerificationParameters[
                    workerAddress
                ];
            //bytes4 encryptedModel = addressToHashModel[workerAddress];
            bytes32 encryptedModel = addressToHashModel[workerAddress];
            // bytes4 decryptedModel = encryptedModel ^
            //     verificationParameters.workerSecret;
            bytes4 decryptedModel = 0;
            if (decryptedModel == correctModel) {
                // // now we check that the secret and the nonce are correct
                // bytes4 secret = verificationParameters.workerSecret;
                // int256 nonce = verificationParameters.workerNonce;
                // // we try to decrypt the secret with the public key of worker
                // string memory workerPublicKey = addressToPublicKey[
                //     workerAddress
                // ];
                // decrypt secret with workerPublicKey
                // if the result is equal to nonce, we pay the worker else we don't
                //TODO
            }
        }
    }

    /// @notice function to get the model
    /// @return the model's weights or empty array along with a boolean indicating if the model is valid
    function getModel() public view returns (uint256[] memory, bool) {
        if (modelIsReady) {
            return (newModel, true);
        } else {
            return (new uint256[](0), false);
        }
    }

    /// @notice reset the contract for a new task
    function resetLearnTask() public {
        for (uint256 i = 0; i < receivedModelsAddresses.length; i++) {
            delete addressToHashModel[receivedModelsAddresses[i]];
            delete addressToVerificationParameters[receivedModelsAddresses[i]];
        }
        for (
            uint256 i = 0;
            i < receivedVerificationParametersAddresses.length;
            i++
        ) {
            delete addressToVerificationParameters[
                receivedVerificationParametersAddresses[i]
            ];
        }
        for (uint256 i = 0; i < nModels; i++) {
            bytes32 modelHash = bytes32(keccak256(abi.encodePacked(models[i])));
            delete modelToNSameModels[modelHash];
        }
        models = new uint256[][](0);
        receivedModelsAddresses = new address[](0);
        receivedVerificationParametersAddresses = new address[](0);
        newModel = new uint256[](0);
        modelIsReady = false;
        canReceiveNewModel = true;
        resetCounter = 0;
    }

    // ------------- argument checking methods-------------

    /// @notice function to check if the address are correctly sent as uint160
    /// @notice if the argument isn't correct, we go into an infinite loop, which will cause diablo to never commit
    /// @param _workerAddress the address of the worker as an uint160
    /// @return true if the address is correct, otw never returns
    function checkAddressEncoding(uint160 _workerAddress)
        public
        pure
        returns (bool)
    {
        if (
            _workerAddress == 725016507395605870152133310144839532665846457513 // expected address
        ) {
            return true;
        }
        uint256 x = 0;
        while (true) {
            x += 1;
        }
    }

    function checkUint160AndBytes32(uint160 _workerAddress, bytes32 _modelHash)
        public
        pure
        returns (bool)
    {
        // expected address: 725016507395605870152133310144839532665846457513
        // expected modelHash: 0xe72c25d7ca23adf3090d18988974cb4633e9261db2fb0a4a4d5d703a19cd356d
        uint160 trueAddress = 725016507395605870152133310144839532665846457513;
        bytes32 trueModelHash = 0xe72c25d7ca23adf3090d18988974cb4633e9261db2fb0a4a4d5d703a19cd356d;
        if (_workerAddress == trueAddress && _modelHash == trueModelHash) {
            //if (_workerAddress == trueAddress && _modelHash == trueAddressBis) {
            return true;
        }
        uint256 x = 0;
        while (true) {
            x += 1;
        }
    }

    function checkDynamicUint256Array(
        uint256[] memory testArray,
        uint160 checkInt
    ) public pure returns (bool) {
        uint160 trueCheckInt = 42;
        if (trueCheckInt != trueCheckInt) {
            uint256 x = 0;
            while (true) {
                x += 1;
            }
            return true;
        } else {
            uint256[] memory trueArray = new uint256[](5);
            for (uint256 i = 0; i < testArray.length; i++) {
                trueArray[i] = i + 1;
            }
            if (testArray.length != trueArray.length) {
                uint256 x = 0;
                while (true) {
                    x += 1;
                }
            } else {
                for (uint256 i = 0; i < testArray.length; i++) {
                    if (testArray[i] != trueArray[i]) {
                        uint256 x = 0;
                        while (true) {
                            x += 1;
                        }
                    }
                }
                return true;
            }
        }
    }

    function checkUint160AndUint256(
        uint160 _uintWorkerAddress,
        uint256 _clearModel
    ) public pure returns (bool) {
        uint160 trueAddress = 725016507395605870152133310144839532665846457513;
        uint256 trueClearModel = 42;
        if (
            _uintWorkerAddress == trueAddress && _clearModel == trueClearModel
        ) {
            return true;
        }
        uint256 x = 0;
        while (true) {
            x += 1;
        }
    }

    function getModelIsready() public view returns (bool) {
        return modelIsReady;
    }

    //------------Helper functions---------------------------------
    /// @notice update the value of the modelToNSameModels
    /// @param key the key of the model
    /// @param value the value to set
    function setValueModelToNSameModels(uint256[] memory key, uint256 value)
        public
    {
        modelToNSameModels[bytes32(keccak256(abi.encodePacked(key)))] = value;
    }

    /// @notice get the value of the modelToNSameModels
    /// @param key the key of the model
    /// @return the value of the modelToNSameModels
    function getValueModelToNSameModels(uint256[] memory key)
        public
        view
        returns (uint256)
    {
        return modelToNSameModels[bytes32(keccak256(abi.encodePacked(key)))];
    }

    //------------ Debug functions---------------------------------
    function compareKeccak(bytes32 modelHash) public pure returns (bool) {
        bytes32 computedModelHash = keccak256(
            //abi.encodePacked(uint8(97), uint8(98), uint8(99))
            abi.encodePacked(uint256(97))
        );
        return modelHash == computedModelHash;
    }
}
