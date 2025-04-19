module jamcat::CatMarketplace {
    use std::{signer, vector, string, option, error, table, event, timestamp};
    use std::address;

    const E_NOT_OWNER: u64 = 1001;
    const E_NOT_LISTED: u64 = 1002;
    const E_EXPIRED: u64 = 1003;

    /// Events
    struct CatMintedEvent has drop, store {
        id: u64,
        name: string::String,
        rarity: u8,
        owner: address,
    }

    struct CatSoldEvent has drop, store {
        id: u64,
        seller: address,
        buyer: address,
        price: u64,
    }

    /// Cat NFT resource
    struct CatNFT has key, store {
        id: u64,
        name: string::String,
        rarity: u8,
        owner: address,
    }

    /// Listings w/ expiration & escrow flag
    struct Listing has key {
        nft_id: u64,
        seller: address,
        price: u64,
        expiration_ts: u64,
        escrowed: bool,
    }

    /// Cat state
    struct CatStore has key {
        cats: table::Table<u64, CatNFT>,
        next_id: u64,
        minted_events: event::EventHandle<CatMintedEvent>,
        sold_events: event::EventHandle<CatSoldEvent>,
    }

    /// Listings for this address
    struct Marketplace has key {
        listings: table::Table<u64, Listing>,
    }

    /// Admin setup
    public fun init(account: &signer) {
        move_to(account, CatStore {
            cats: table::new<u64, CatNFT>(),
            next_id: 1,
            minted_events: event::new_event_handle<CatMintedEvent>(account),
            sold_events: event::new_event_handle<CatSoldEvent>(account),
        });
        move_to(account, Marketplace {
            listings: table::new<u64, Listing>(),
        });
    }

    /// Mint cat
    public fun mint_cat(account: &signer, name: string::String, rarity: u8) {
        let sender = signer::address_of(account);
        let store = borrow_global_mut<CatStore>(sender);
        let id = store.next_id;
        store.next_id = id + 1;

        let cat = CatNFT {
            id,
            name: name.clone(),
            rarity,
            owner: sender,
        };

        table::add(&mut store.cats, id, cat);
        event::emit_event(&mut store.minted_events, CatMintedEvent {
            id,
            name,
            rarity,
            owner: sender,
        });
    }

    /// List with escrow
    public fun list_cat(account: &signer, cat_id: u64, price: u64, ttl_secs: u64) {
        let sender = signer::address_of(account);
        let store = borrow_global_mut<CatStore>(sender);
        let cat = table::borrow_mut(&mut store.cats, cat_id);

        assert!(cat.owner == sender, E_NOT_OWNER);

        let expires = timestamp::now_seconds() + ttl_secs;

        let market = borrow_global_mut<Marketplace>(sender);
        table::add(&mut market.listings, cat_id, Listing {
            nft_id: cat_id,
            seller: sender,
            price,
            expiration_ts: expires,
            escrowed: true,
        });

        // Escrow = set owner to 0x0 temporarily
        cat.owner = @0x0;
    }

    /// Buy cat
    public fun buy_cat(buyer: &signer, seller_addr: address, cat_id: u64) {
        let now = timestamp::now_seconds();
        let buyer_addr = signer::address_of(buyer);

        let market = borrow_global_mut<Marketplace>(seller_addr);
        let listing = table::remove(&mut market.listings, cat_id);

        assert!(listing.expiration_ts >= now, E_EXPIRED);

        let store = borrow_global_mut<CatStore>(seller_addr);
        let cat = table::borrow_mut(&mut store.cats, cat_id);

        cat.owner = buyer_addr;

        event::emit_event(&mut store.sold_events, CatSoldEvent {
            id: cat_id,
            seller: listing.seller,
            buyer: buyer_addr,
            price: listing.price,
        });

        // TODO: Token transfer here with real coin
    }

    /// Cancel listing and return escrowed NFT
    public fun cancel_listing(account: &signer, cat_id: u64) {
        let sender = signer::address_of(account);
        let market = borrow_global_mut<Marketplace>(sender);
        let listing = table::remove(&mut market.listings, cat_id);

        let store = borrow_global_mut<CatStore>(sender);
        let cat = table::borrow_mut(&mut store.cats, cat_id);

        cat.owner = sender;
    }

    /// View NFT
    public fun get_cat(owner: address, id: u64): &CatNFT {
        let store = borrow_global<CatStore>(owner);
        table::borrow(&store.cats, id)
    }

    /// Clean expired listings
    public fun purge_expired(account: &signer, id: u64) {
        let now = timestamp::now_seconds();
        let sender = signer::address_of(account);

        let market = borrow_global_mut<Marketplace>(sender);
        let listing = table::borrow(&market.listings, id);

        assert!(listing.expiration_ts < now, E_EXPIRED);
        table::remove(&mut market.listings, id);
    }
}
