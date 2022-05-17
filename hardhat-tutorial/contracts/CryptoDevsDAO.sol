//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interface for the FakeNFTMarketplace
interface IFakeNFTMarketplace {
    
    function purchase(uint256 _tokenId) external payable;
  
    function getPrice() external view returns(uint256);
  
    function available(uint256 _tokenId) external view returns(bool);
}

// Interface for CryptoDevsNFT
interface ICryptoDevsNFT {
    function balanceOf(address owner) external view returns (uint256);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns(uint256);

}

contract CryptoDevsDAO is Ownable {

 enum Vote{
     YAY,
     NAY
 }

 struct Proposal {
    // nftTokenId - the tokenID of the NFT to purchase from FakeNFTMarketplace if the proposal passes
    uint256 nftTokenId;
    // deadline - the UNIX timestamp until which this proposal is active. Proposal can be executed after the deadline has been exceeded.
    uint256 deadline;
    // yayVotes - number of yay votes for this proposal
    uint256 yayVotes;
    // nayVotes - number of nay votes for this proposal
    uint256 nayVotes;
    // executed - whether or not this proposal has been executed yet. Cannot be executed before the deadline has been exceeded.
    bool executed;
    // voters - a mapping of CryptoDevsNFT tokenIDs to booleans indicating whether that NFT has already been used to cast a vote or not
    mapping(uint256 => bool) voters;
}

// Create a mapping of ID to Proposal
mapping(uint256 => Proposal) public proposals;
// Number of proposals that have been created
uint256 public numProposals; 

IFakeNFTMarketplace nftMarketplace;
ICryptoDevsNFT cryptoDevsNFT;

constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
    nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
    cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
}

modifier nftHolderOnly() {
    require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A DAO_MEMBER");
    _;
}

modifier activeProposalOnly(uint256 proposalIndex) {
    require(proposals[proposalIndex].deadline > block.timestamp, "PROPOSAL_INACTIVE");
    _;
}

modifier inactiveProposal(uint256 proposalIndex) {
    require(proposals[proposalIndex].deadline <= block.timestamp, "PROPOSAL_ACTIVE");
    require(proposals[proposalIndex].executed == false, "ALREADY_EXECUTED");
    _;

}

// createProposal allows a CryptoDevsNFT holder to create a new proposal in DAO
function createProposal(uint256 _nftTokenId) external nftHolderOnly returns(uint256){
    require(nftMarketplace.available(_nftTokenId), "NOT_FOR_SALE");
    Proposal storage proposal = proposals[numProposals];
    
    proposal.nftTokenId = _nftTokenId;

   // deadline is current time + minutes
    proposal.deadline = block.timestamp + 5 minutes;
    
    numProposals++;

    return numProposals-1;

}
 //  voteOnProposal allows a CryptoDevsNFT holder to cast their vote on an active proposal
 function voteOnProposal(uint256 proposalIndex, Vote vote) external nftHolderOnly activeProposalOnly(proposalIndex){
     Proposal storage proposal = proposals[proposalIndex];
     
     uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
     uint256 numVotes;

     for(uint256 i = 0; i<voterNFTBalance; i++){
         uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
         if (proposal.voters[tokenId]==false){
             numVotes++;
             proposal.voters[tokenId] = true;
         }
     }
     require(numVotes > 0, "ALREADY_VOTED");
     
     if(vote == Vote.YAY){
         proposal.yayVotes += numVotes;
     }else{
         proposal.nayVotes += numVotes;
     }

 }

 // executeProposal allows any CryptoDevsNFT holder to execute a proposal after it's deadline has been exceeded
function executeProposal(uint256 proposalIndex) external nftHolderOnly inactiveProposal(proposalIndex){
    Proposal storage proposal = proposals[proposalIndex];
    
    //Did the proposal pass?
    if(proposal.yayVotes > proposal.nayVotes) {
        uint256 nftPrice = nftMarketplace.getPrice();
        require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
        nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
    }
    proposal.executed = true;
}

// withdrawEther allows the contract owner (deployer) to withdraw the ETH from the contract
function withdrawEther() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
}

// The following two functions allow the contract to accept ETH deposits
// directly from a wallet without calling a function
receive() external payable {}

fallback() external payable {}

}