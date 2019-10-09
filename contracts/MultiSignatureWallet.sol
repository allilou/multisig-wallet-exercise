pragma solidity ^0.5.0;

contract MultiSignatureWallet {

    struct Transaction {
      bool executed;
      address destination;
      uint value;
      bytes data;
    }

    address[] public owners;
    uint public required;
    mapping (address => bool) public isOwner;

    uint public transactionsCount;
    mapping (uint => Transaction) public transactions;

    mapping (uint => mapping (address => bool)) public confirmations;

    event Deposit(address indexed sender, uint value);
    event Submission(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);

    /// @dev Fallback function allows to deposit ether.
    function()
    	external
        payable
    {
        if (msg.value > 0) {
           emit Deposit(msg.sender, msg.value);
	}
    }


    modifier validRequirement(uint ownerCount, uint _required) {
        if (   _required > ownerCount || _required == 0 || ownerCount == 0)
            revert("Req not met");
        _;
    }

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] memory _owners, uint _required) public
    validRequirement(_owners.length,  _required)
    {
        for (uint i = 0 ; i < _owners.length; i++)
        {
            isOwner[_owners[i]] = true;
        }
        required = _required;
        owners = _owners;
        transactionsCount = 0;

    }


    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(address destination, uint value, bytes memory data)
    public
    returns (uint transactionId) {
        require(isOwner[msg.sender]);
        transactionId = addTransaction(destination, value, data);
        confirmTransaction(transactionId);
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address destination, uint value, bytes memory data)
    internal
    returns (uint transactionId) {
        transactionId = transactionsCount;

        transactions[transactionId].executed = false;
        transactions[transactionId].destination = destination;
        transactions[transactionId].value = value;
        transactions[transactionId].data = data;

        //emit Submission(transactionId);

        transactionsCount += 1;
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId) public {
        require(isOwner[msg.sender]);
        require(int(transactions[transactionId].destination) != 0);
        require(confirmations[transactionId][msg.sender] == false);

        confirmations[transactionId][msg.sender] = true;
        //emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);

    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public {
        // require(transactions[transactionId].executed == false);

        if (isConfirmed(transactionId)) {
            Transaction storage t = transactions[transactionId];  // using the "storage" keyword makes "t" a pointer to storage
            t.executed = true;
            (bool success, bytes memory returnedData) = t.destination.call.value(t.value)(t.data);
            if (success)
                emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                t.executed = false;
            }
        }

    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) public {}

		/*
		 * (Possible) Helper Functions
		 */
    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) internal view returns (bool) {
        uint count = 0;
        for (uint i = 0; i <= owners.length ; i++){
            if (confirmations[transactionId][owners[i]] == true)
            count += 1;
                 
            if (count >= required) {
                return true;
            }
        }
    }
}
