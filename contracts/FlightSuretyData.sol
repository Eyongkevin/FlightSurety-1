pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    //using SafeMath for uint;
    using SafeMath for uint256;
    

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    
    // Struct used to hold registered airlines
    struct Airlines {
        bool isRegistered;
        bool isOperational;
    }

    struct Insurance {
        address passenger;
        uint256 amount;
    
    }
    struct Fund {
        uint256 amount;
    }
    struct Voters {
        bool status;
    }

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    mapping(address => uint256) private authorizedCaller;
    mapping(address => Airlines) airlines;                             // mapping address to struct which holds registered airlines.
    mapping(address => Insurance) insurance;                             // Airline address maps to struct
    mapping(address => uint256) balances;
    mapping(address => Fund) fund;
    address[] multiCalls = new address[](0);
    mapping(address => uint) private voteCount;
    mapping(address => Voters) voters;
 

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AuthorizedContract(address authContract);
    event DeAuthorizedContract(address authContract);


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    // ------------------- Get and Set function for multiCalls -------------------------

    function setmultiCalls(address account) private {
        multiCalls.push(account);
    }
    function multiCallsLength() external requireIsOperational returns(uint){
        return multiCalls.length;
    }


    //----------------- Set and Get function for Airline struct ------------------------------
    function getAirlineOperatingStatus(address account) external requireIsOperational returns(bool){
        return airlines[account].isOperational;
    }

    function setAirlineOperatingStatus(address account, bool status) external requireIsOperational {
        airlines[account].isOperational = status;
    }

    function getAirlineRegistrationStatus(address account) external requireIsOperational returns(bool){
        return airlines[account].isRegistered;
    }

    function getVoteCounter(address account) external requireIsOperational returns(uint){
        return voteCount[account];
    }
    function resetVoteCounter(address account) external requireIsOperational{
        delete voteCount[account];
    }
    function getVoterStatus(address voter) external requireIsOperational returns(bool){
        return voters[voter].status;
    }
    function addVoters(address voter) external{
        voters[voter] = Voters({
            status: true
        });
    }
    function addVoterCounter(address airline, uint count) external{
        uint vote = voteCount[airline];
        voteCount[airline] = vote.add(count); 
    }



    // ---------------------------- Insurance registration --------------------------
    function registerInsurance(address airline, address passenger, uint256 amount) external requireIsOperational{
        insurance[airline] = Insurance({
            passenger: passenger,
            amount: amount
        });
        uint256 getFund = fund[airline].amount;
        fund[airline].amount = getFund.add(amount);
    }

    //-----------------------------Fund recording -------------------------
    function fundAirline(address airline, uint256 amount) external{
        fund[airline] = Fund({
            amount: amount
        });

    }
    function getAirlineFunding(address airline) external returns(uint256){
        return fund[airline].amount;
    }


    function authorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        authorizedCaller[contractAddress] = 1;
        emit AuthorizedContract(contractAddress);
    }

    function deauthorizeContract
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        delete authorizedCaller[contractAddress];
        emit DeAuthorizedContract(contractAddress);
    }


   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function _registerAirline
                            (   
                                address account,
                                bool isOperational
                            )
                            external
                            requireIsOperational
    {
        // isRegistered is Always true for a registered airline
        // isOperational is only true when the airline has submited funding of 10 ether
        airlines[account] = Airlines({
            isRegistered: true,
            isOperational: isOperational
        });
        setmultiCalls(account);
    }

    /**
    * @dev Check if an airline is registered
    *
    * @return A bool that indicates if the airline is registered
    */   
    function isAirline
                            (
                                address account
                            )
                            external
                            
                            returns(bool)
    {
        require(account != address(0), "'account' must be a valid address.");

        return airlines[account].isRegistered;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address airline,
                                    address passenger,
                                    uint256 amount
                                )
                                external
                                requireIsOperational
                              
    {
        // Get expected amount to be credited
        uint256 required_amount =insurance[airline].amount.mul(3).div(2);

        require(insurance[airline].passenger == passenger, "Passenger is not insured");
        require(required_amount == amount, "The amount to be credited is not as espected");
        require((passenger != address(0)) && (airline != address(0)), "'accounts' must be  valid address.");


        // Store amount to be credited in passenger balance
        balances[passenger] = amount;

    }

    function withdraw
                        (
                            address passenger
                        )
                        external
                        
                        requireIsOperational
                        returns(uint256)
    {
        uint256 withdraw_cash = balances[passenger];

        delete balances[passenger];
        return withdraw_cash;


    }


    function getInsuredPassenger_amount(address airline) external requireIsOperational  returns(address, uint256){
        return (insurance[airline].passenger,insurance[airline].amount);
    }

    function getPassengerCredit(address passenger) external requireIsOperational returns(uint256){
        return balances[passenger];
    }  


    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    /*
    function() 
                            external 
                            payable 
    {
        fund();
    }
    */


}

