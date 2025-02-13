from web3 import Web3


class EncryptionWorker:
    def __init__(self, address, private_key, id, contract):
        self.address = address
        self.private_key = private_key
        self.contract = contract
        self.id = id
        self.model = None

    def send_encrypted_model(self, model: [int]) -> bool:
        """Send the encrypted model to the blockchain
        Args:
            model ([int]): model's weights
        Returns:
            bool: True if the transaction was successful, False otherwise
        """
        # first we learn a new model
        # model = self.model[0]
        self.model = model
        # then we add the int value of worker's address to the model (i.e to prove that the worker
        # is the one who learned the model)
        int_address = int(self.address, 16)
        address = self.address
        # encrypted_model = [model + int_address]
        encrypted_model = [weight + int_address for weight in self.model]
        # TODO can be udpated to use the x10 times faster method as in arguments
        model_hash = Web3.solidityKeccak(
            ["uint256[]"], [encrypted_model]).hex()
        res = self.contract.send_hashed_model(
            model_hash, address, self.private_key
        )
        if len(res) == 2:
            return res[0] is True and res[1] is True
        return False

    def compare_hash(self):
        model = [97]
        # == '0x4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45'
        # model_hash = Web3.solidityKeccak(["uint8", "uint8", "uint8"], self.model).hex()
        model_hash = Web3.solidityKeccak(
            ["uint256"], model).hex()
        print("model_hash", model_hash)
        res = self.contract.compare_hash(
            model_hash,
            self.address,
            self.private_key
        )
        print("send_encrypted_model_v2: return value", res)
        return res

    def check_can_send_verification_parameters(self) -> bool:
        # check the number of submitted models from the smart contract
        return self.contract.check_can_send_verification_parameters(self.address)

    def send_verifications(self, good_model, good_address) -> bool:
        """Send the verifications to the blockchain
        The verifications are the nounce and the secret key
        Args:
            good_model(bool): If True send correct model, else a model which din't match the one we send before
            good_address(bool): True if the address is good, False otherwise
        Returns:
            bool: True if the transaction was successful, False otherwise
        """
        address = self.address if good_address else "0x0000000000000000000000000000000000000042"  # dummy address
        # clear_model = self.model[0] if good_model else 0
        clear_model = self.model if good_model else [0] * len(self.model)
        return self.contract.send_verifications_parameters(
            clear_model, address, self.private_key
        )

    def send_verifications_compressed(self, good_model, good_address) -> bool:
        """Send the verifications to the blockchain
        The verifications are the worker address followed by first 1k weights of the model (we do so as
        in diablo we cannot use txs of more than ~1k parameters)
        Args:
            good_model(bool): If True send correct model, else a model which din't match the one we send before
            good_address(bool): True if the address is good, False otherwise
        Returns:
            bool: True if the transaction was successful, False otherwise
        """
        address = self.address if good_address else "0x0000000000000000000000000000000000000042"  # dummy address
        # clear_model = self.model[0] if good_model else 0
        clear_model = self.model[:1000] if good_model else [0] * 1000
        return self.contract.send_verifications_parameters(
            clear_model, address, self.private_key
        )
