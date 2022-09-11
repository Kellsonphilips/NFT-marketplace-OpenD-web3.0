import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import NFTActorClass "../nft/nft";
import HashMap "mo:base/HashMap";
import List "mo:base/List";
import Iter "mo:base/Iter";

actor OpenD {
     Debug.print("Hi!, Everything is perfectly fine!");

    //creating a new datatype for our NFT Listings handling 
    private type Listing = {
        itemOwner: Principal;
        itemPrice: Nat;
    };

    //creating data storage with HashMap
    var mapOfNFTs = HashMap.HashMap<Principal, NFTActorClass.NFT>(1, Principal.equal, Principal.hash);
    //creating data storage for minted NFT owners using List and HashMap
    var mapOfOwners = HashMap.HashMap<Principal, List.List<Principal>>(1, Principal.equal, Principal.hash);
    //Creating another HashMap which is going to keep track of the Listings of NFTs in our NFT market
    var mapOfListings = HashMap.HashMap<Principal, Listing>(1, Principal.equal, Principal.hash);


   

    public shared(msg) func mint(imgData: [Nat8], name: Text) : async Principal {
        let owner : Principal = msg.caller;

        Debug.print(debug_show(Cycles.balance()));
        Cycles.add(100_500_000_000);
        let newNFT = await NFTActorClass.NFT(name, owner, imgData);
        Debug.print(debug_show(Cycles.balance()));


        let newNFTPrincipal = await newNFT.getCanisterId();
        // Adding every new minted nft to our HashMap
        mapOfNFTs.put(newNFTPrincipal, newNFT);
        addToOwnerShipMap(owner, newNFTPrincipal);

        return newNFTPrincipal
    };

    // getting hold of NFT owners and storing their different NFTs as categorised
    // we will need a private function 

    private func addToOwnerShipMap(owner: Principal, nftId: Principal) {
        // we need a way to deal with the options if the ownership returns null or a result
        // This serves in a case where the user do not have any NFT minted already
        // so we use switch case
        var ownedNFTs : List.List<Principal> = switch (mapOfOwners.get(owner)) {
            case null List.nil<Principal>();
            case (?result) result;
        };
        
        // updating the List of NFTs the owner owned whenever they minted a new NFT
        ownedNFTs := List.push(nftId, ownedNFTs);
        mapOfOwners.put(owner, ownedNFTs);
    };

    public query func getOriginalOwner(id: Principal) : async Principal {
        var listing : Listing = switch (mapOfListings.get(id)) {
            case null return Principal.fromText("");
            case (?result) result;
        };

        return listing.itemOwner;
    };
 
    // fetching the list of Ids of owners and their NFTs to be rendered in our FrontEnd
    // It's going to be array of items the user own
    // user datatype is a Principal obviously and we need to match it to the mapOfOwners Principal canister Id
    // before it can be rendered

    public query func getOwnedNFTs(user: Principal) : async [Principal] {
        var userNFTs : List.List<Principal> = switch (mapOfOwners.get(user)) {
            case null List.nil<Principal>();
            case (?result) result;
        };
        return List.toArray(userNFTs);
    };

    public query func getListedNFTs() : async [Principal] {
       let ids = Iter.toArray(mapOfListings.keys());
       return ids;
    };

    public shared(msg) func listItem(id: Principal, price: Nat) :  async Text {
        var item : NFTActorClass.NFT = switch (mapOfNFTs.get(id)) {
            case null return "NFT does not exist.";
            case (?result) result;
        };

        let owner = await item.getOwner();
        if (Principal.equal(owner, msg.caller)) {
            let newListing : Listing = {
                itemOwner = owner;
                itemPrice = price;
            };
            mapOfListings.put(id, newListing);
            return "Success";
        } else {
            return " You don't own this NFT";
        };
    };

    public query func getOpenDCanisterId() : async Principal {
        return Principal.fromActor(OpenD);
    };

    public query func isListed(id: Principal) : async Bool {
        if (mapOfListings.get(id) == null) {
            return false;
        } else { 
            return true;
        };
    };

    public query func getListedNFTPrice(id: Principal) : async Nat {
        var listing : Listing = switch (mapOfListings.get(id)) {
            case null return 0;
            case (?result) result;
        };

        return listing.itemPrice;
    };

    // Transfering the purchased NFT to the new owner to complete the transaction between seller of NFT
    // And NFT buyer
    public shared(msg) func completePurchase(id: Principal, ownerId: Principal, newOwnerId: Principal) : async Text {
        var purchasedNFT : NFTActorClass.NFT = switch (mapOfNFTs.get(id)) {
            case null return "NFT does not exist!";
            case (?result) result;
        };


        // completing the Transfer of purchased NFT to the new owner
        let transferResult = await purchasedNFT.transferOnwership(newOwnerId);
        if (transferResult == "Success") {
            // after transfer delete the nft from the previous owner List
            mapOfListings.delete(id);
            var ownedNFTs : List.List<Principal> = switch (mapOfOwners.get(ownerId)) {
                case null List.nil<Principal>();
                case (?result) result;
            };

            // looping through to check for the purchased NFT id
            // if the purchased id is available in the listItemId the it return true 
            // then we add the purchased NFT from the List and when false we omit it from the List
            ownedNFTs := List.filter(ownedNFTs, func (listItemId: Principal) : Bool {
                return listItemId != id;
            });
            // add the NFT to the newOwner 
            addToOwnerShipMap(newOwnerId, id);
            // if everything went successfully 
            return "Success";
        } else {
            return transferResult;
        };

    }
};
