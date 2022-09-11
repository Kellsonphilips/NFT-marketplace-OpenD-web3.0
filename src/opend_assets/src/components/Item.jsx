import React, { useEffect, useState } from "react";
import logo from "../../assets/logo.png";
import { Actor, HttpAgent } from "@dfinity/agent";
import { idlFactory } from "../../../declarations/nft";
import { idlFactory as tokenIdlFactory } from "../../../declarations/token";
import { Principal } from "@dfinity/principal";
import Button from "./Button";
import { opend } from "../../../declarations/opend";
import CURRENT_USER_ID from "../index";
import PriceLabel from "./PriceLabel";

function Item(props) {

  const [name, setName] = useState();
  const [owner, setOwner] = useState();
  const [image, setImage] = useState();
  const [button, setButton] = useState();
  const [priceInput, setPriceInput] = useState();
  const [loaderHidden, setLoaderHidden] = useState(true);
  const [blur, setBlur] = useState();
  const [sellStatus, setSellStatus] = useState("");
  const [priceLabel, setPriceLable] = useState();
  const [shouldDisplay, setShoulddisplay] = useState(true);

  const id = props.id;

  // Using the http to fetch our nft from IC blockchain
  // we are working locally so I will provide the localhost
  const localHost = "http://localhost:8080";
  // creating a new http agent from the agent package on Dfinity
  const agent = new HttpAgent({host: localHost});
  //When deploying live we need to remove this code below fetchRootKey.
  agent.fetchRootKey();

  let NFTActor;

  // Loading our minted NFT from our canister using the idlFactory from the declaration of our actor class in BackEnd
  async function loadNFT() {
    NFTActor = await Actor.createActor(idlFactory, {
      agent,
      canisterId: id,
    });

    // we get hold of our nft name, owner and the nft image and pass it to our frontEnd using useState
    const name = await NFTActor.getName();
    setName(name);

    const owner = await NFTActor.getOwner();
    setOwner(owner.toText());

    // image content is in Nat8
    const imageData = await NFTActor.getAsset();
    //converting it to what javascript read using Uint8Array
    const imageContent = new Uint8Array(imageData);
    // converting imageContent to a URl using Blob
    const image = URL.createObjectURL(new Blob([imageContent.buffer], {type: "image/png"}));
    setImage(image);

    if (props.role == "collection") {
      const nftIsListed = await opend.isListed(props.id);
      if (nftIsListed) {
        setOwner("openD");
        setBlur({ filter: "blur(4px)" });
        setSellStatus("Listed");
      } else {
        setButton(<Button handleClick={handleSell} text={"Sell"} />);
      }
    } else if (props.role == "discover") {
      const originalOwner = await opend.getOriginalOwner(props.id);

      if (originalOwner.toText() != CURRENT_USER_ID.toText()) {
        setButton(<Button handleClick={handleBuy} text={"Buy"} />);
      }

      const price = await opend.getListedNFTPrice(props.id);
      setPriceLable(<PriceLabel sellPrice={price.toString()} />);

    }

  }

  useEffect(() => {
    loadNFT();
  }, []);

  let price;

  function handleSell() {
    console.log("Sell Clicked");
    setPriceInput(<input
        placeholder="Price in DK"
        type="number"
        className="price-input"
        value={price}
        onChange={(event) => (price=event.target.value)}
      />)
      setButton(<Button handleClick={sellItem} text={"Confirm"} />);
  }


  async function sellItem() {
    setBlur({filter: "blur(4px)"});
    setLoaderHidden(false);
    console.log("Item price = " + price);
    const listingResult = await opend.listItem(props.id, Number(price));
    console.log("listings : " + listingResult);
    if (listingResult == "Success") {
      const openDId = await opend.getOpenDCanisterId();
      const transferResult = await NFTActor.transferOnwership(openDId);
      console.log("transfer : " + transferResult);
      if (transferResult == "Success") {
        setLoaderHidden(true);
        setButton();
        setPriceInput();
        setOwner("openD");
        setSellStatus("Listed");
      };
    };
  }

  async function handleBuy() {
    console.log("Buy button was triggered");
    setLoaderHidden(false);
    const tokenActor = await Actor.createActor(tokenIdlFactory, {
      agent,
      canisterId: Principal.fromText("txssk-maaaa-aaaaa-aaanq-cai"),
    });

    const sellerId = await opend.getOriginalOwner(props.id);
    const itemPrice = await opend.getListedNFTPrice(props.id);

    const result = await tokenActor.transfer(sellerId, itemPrice);
    console.log(result);

    if (result == "Success") {
      const transferResult = await opend.completePurchase(props.id, sellerId, CURRENT_USER_ID);
      console.log("purchase: " + transferResult);
      setLoaderHidden(true);
      setShoulddisplay(false);
    }
   
  }

  return (
    <div style={{ display: shouldDisplay ? "inline" : "none"}} className="disGrid-item">
      <div className="disPaper-root disCard-root makeStyles-root-17 disPaper-elevation1 disPaper-rounded">
        <img
          className="disCardMedia-root makeStyles-image-19 disCardMedia-media disCardMedia-img"
          src={image}
          style={blur}
        />
        <div hidden={loaderHidden} className="lds-ellipsis">
          <div></div>
          <div></div>
          <div></div>
          <div></div>
        </div>
        <div className="disCardContent-root">
          {priceLabel}
          <h2 className="disTypography-root makeStyles-bodyText-24 disTypography-h5 disTypography-gutterBottom">
            {name}
            <span className="purple-text"> {sellStatus}</span>
          </h2>
          <p className="disTypography-root makeStyles-bodyText-24 disTypography-body2 disTypography-colorTextSecondary">
            Owner: {owner}
          </p>
          {priceInput}
          {button}
        </div>
      </div>
    </div>
  );
}

export default Item;
