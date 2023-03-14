module warmup::Warmup {
    use std::string::{Self, String};

    use sui::url;
    use sui::balance;
    use sui::object::{Self, ID};
    use sui::transfer::{Self, transfer};
    use sui::tx_context::{Self, TxContext};

    use nft_protocol::nft::{Self, Nft};
    use nft_protocol::tags;
    use nft_protocol::royalty;
    use nft_protocol::display;
    use nft_protocol::creators;
    use nft_protocol::witness;
    use nft_protocol::transfer_allowlist_domain;
    use nft_protocol::transfer_allowlist::{Self, CollectionControlCap};
    use nft_protocol::royalties::{Self, TradePayment};
    use nft_protocol::collection::{Self, Collection};
    use nft_protocol::mint_cap::{Self, MintCap};
    use nft_protocol::listing::{Self, Listing};

    /// One time witness is only instantiated in the init method
    struct WARMUP has drop {}

    /// Can be used for authorization of other actions post-creation. It is
    /// vital that this struct is not freely given to any contract, because it
    /// serves as an auth token.
    struct Witness has drop {}

    fun init(witness: WARMUP, ctx: &mut TxContext) {
         let sender = tx_context::sender(ctx);

        let (mint_cap, collection) = collection::create(&witness, ctx);

        collection::add_domain(
            &Witness {},
            &mut collection,
            creators::from_address<WARMUP, Witness>(
                &Witness {}, sender,
            ),
        );

        // Register custom domains
        display::add_collection_display_domain(
            &Witness {},
            &mut collection,
            string::utf8(b"{{ name }}"),
            string::utf8(b"{{ description }}"),
        );

        display::add_collection_url_domain(
            &Witness {},
            &mut collection,
            sui::url::new_unsafe_from_bytes(b"{{ url }}"),
        );

        display::add_collection_symbol_domain(
            &Witness {},
            &mut collection,
            string::utf8(b"{{ symbol }}"),
        );

        let royalty = royalty::from_address(sender, ctx);
        royalty::add_proportional_royalty(&mut royalty, 0);
        royalty::add_royalty_domain(&Witness {}, &mut collection, royalty);

        let tags = tags::empty(ctx);
        tags::add_tag(&mut tags, tags::art());
        tags::add_collection_tag_domain(&Witness {}, &mut collection, tags);

        let allowlist = transfer_allowlist::create(&Witness {}, ctx);
        transfer_allowlist::insert_collection<WARMUP, Witness>(
            &Witness {},
            witness::from_witness(&Witness {}),
            &mut allowlist,
        );

        collection::add_domain(
            &Witness {},
            &mut collection,
            transfer_allowlist_domain::from_id(object::id(&allowlist)),
        );
        
        let col_cap: CollectionControlCap<WARMUP> = transfer_allowlist::create_collection_cap<WARMUP>(
            witness::from_witness(&Witness {}),
            ctx
        );
        transfer::share_object(allowlist);

        transfer::transfer(col_cap, tx_context::sender(ctx));

        transfer::transfer(mint_cap, sender);
        transfer::share_object(collection);
    }

    public entry fun collect_royalty<FT>(
        payment: &mut TradePayment<WARMUP, FT>,
        collection: &mut Collection<WARMUP>,
        ctx: &mut TxContext,
    ) {
        let b = royalties::balance_mut(Witness {}, payment);

        let domain = royalty::royalty_domain(collection);
        let royalty_owed =
            royalty::calculate_proportional_royalty(domain, balance::value(b));

        royalty::collect_royalty(collection, b, royalty_owed);
        royalties::transfer_remaining_to_beneficiary(Witness {}, payment, ctx);
    }

    public entry fun mint_nft_to_listing(
        name: String,
        description: String,
        url: vector<u8>,
        attribute_keys: vector<String>,
        attribute_values: vector<String>,
        mint_cap: &mut MintCap<WARMUP>,
        listing: &mut Listing,
        inventory_id: ID,
        ctx: &mut TxContext,
    ) {
        let nft = mint_nft_(name, description, url, attribute_keys, attribute_values, mint_cap, ctx);

        listing::add_nft(listing, inventory_id, nft, ctx);
    }

    public entry fun mint_nft(
        name: String,
        description: String,
        url: vector<u8>,
        attribute_keys: vector<String>,
        attribute_values: vector<String>,
        mint_cap: &mut MintCap<WARMUP>,
        ctx: &mut TxContext,
    ) {
        let nft = mint_nft_(name, description, url, attribute_keys, attribute_values, mint_cap, ctx);

        transfer(nft, tx_context::sender(ctx));
    }

    fun mint_nft_(
        name: String,
        description: String,
        url: vector<u8>,
        attribute_keys: vector<String>,
        attribute_values: vector<String>,
        mint_cap: &mut MintCap<WARMUP>,
        ctx: &mut TxContext,
    ): Nft<WARMUP> {
        let url = url::new_unsafe_from_bytes(url);
        let nft = nft::from_mint_cap(mint_cap, name, url, ctx);

        display::add_display_domain(
            &Witness {}, 
            &mut nft,
            name,
            description
        );

        display::add_url_domain(
            &Witness {}, 
            &mut nft,
            url,
        );

        display::add_attributes_domain_from_vec(
            &Witness {}, 
            &mut nft,
            attribute_keys,
            attribute_values,
        );

        display::add_collection_id_domain(
            &Witness {}, &mut nft, mint_cap::collection_id(mint_cap),
        );

        nft
    }
}
