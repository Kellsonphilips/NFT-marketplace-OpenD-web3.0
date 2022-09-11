
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";

// To have access to our canisters programatically
// We will have to use actor class and specify their inputs

actor class NFT (name: Text, owner: Principal, content: [Nat8]) = this {
    // Checking if our canister is working properly
    Debug.print("Hello, It's working well!");

    private let itemName = name;
    private var nftOwner = owner;
    private let imageBytes = content;

    public query func getName() : async Text {
        return itemName;
    };

    public query func getOwner() : async Principal {
        return nftOwner;
    };

    public query func getAsset() : async [Nat8] {
        return imageBytes;
    };

    // getting hold of all the inputs for the function NFT with this keyword
    // this will enable us get hold of the principal id of the user
    public query func getCanisterId(): async Principal {
        return Principal.fromActor(this);
    };

    public shared(msg) func transferOnwership(newOnwer: Principal) : async Text {
        if (msg.caller == nftOwner) {
            nftOwner := newOnwer;
            return "Success";
        } else {
            return "Error: Not initiated by NFT owner.";
        };
    };
}