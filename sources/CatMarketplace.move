module jamcat::CatMarketplace {
    use std::signer;
    use std::vector;
    use std::string;
    use std::option;
    use std::error;
    use std::table;

    /// Resource: 🐱 Cat NFT
    struct CatNFT has key {
        id: u64,
        name: string::String,
        rarity: u8,
        owner: address,
    }

    /// Resource: Listing for sale
    struct Listing has key {
        nft_id: u64,
        seller: address,
        price: u64,
    }

    /// Global state: storage of cats
    struct CatStore has key {
        cats: table::Table<u64, CatNFT>,
        next_id: u64,
    }

    /// Global listing storage
    struct Marketplace has key {
        listings: table::Table<u64, Listing>,
    }

    // Initializes the contract state for the deployer
    public fun init(account: &signer) {
        move_to(account, CatStore {
            cats: table::new<u64, CatNFT>(),
            next_id: 1,
        });
        move_to(account, Marketplace {
            listings: table::new<u64, Listing>(),
        });
    }

    // Mint a new cat NFT 🐱
    public fun mint_cat(account: &signer, name: string::String, rarity: u8) {
        let sender = signer::address_of(account);
        let store = borrow_global_mut<CatStore>(sender);

        let id = store.next_id;
        store.next_id = id + 1;

        let cat = CatNFT {
            id,
            name,
            rarity,
            owner: sender,
        };

        table::add(&mut store.cats, id, cat);
    }

    // List a cat for sale 💸
    public fun list_cat(account: &signer, cat_id: u64, price: u64) {
        let sender = signer::address_of(account);
        let store = borrow_global_mut<CatStore>(sender);
        let cat = table::borrow_mut(&mut store.cats, cat_id);
        
        assert!(cat.owner == sender, 1001); // only owner can list

        let market = borrow_global_mut<Marketplace>(sender);
        table::add(&mut market.listings, cat_id, Listing {
            nft_id: cat_id,
            seller: sender,
            price,
        });
    }

    // Buy a listed cat (pseudo-payment logic) 🛒
    public fun buy_cat(buyer: &signer, seller_addr: address, cat_id: u64) {
        let buyer_addr = signer::address_of(buyer);
        let market = borrow_global_mut<Marketplace>(seller_addr);
        let listing = table::remove(&mut market.listings, cat_id);

        let store = borrow_global_mut<CatStore>(seller_addr);
        let cat = table::borrow_mut(&mut store.cats, cat_id);

        // Transfer ownership
        cat.owner = buyer_addr;

        // (optional) implement Coin transfer or burn here!
        // E.g., jamcat::CatCoin::transfer(...)
    }

    /// View cat info (returns full struct)
    public fun get_cat(account: address, id: u64): &CatNFT {
        let store = borrow_global<CatStore>(account);
        table::borrow(&store.cats, id)
    }
}
