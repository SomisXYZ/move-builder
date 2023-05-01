module module_name::module_name {
    use std::ascii;
    use std::option;
    use std::string::{Self, String};
    use std::vector::{Self};

    use sui::url::{Self, Url};
    use sui::display;
    use sui::transfer;
    use sui::package::{Self, Publisher};
    use sui::object::{Self, ID, UID};
    use sui::vec_set;
    use sui::tx_context::{Self, TxContext};

    use nft_protocol::mint_event;
    use nft_protocol::mint_cap;
    use nft_protocol::creators;
    use nft_protocol::attributes::{Self, Attributes};
    use nft_protocol::collection;
    use nft_protocol::display_info;
    use nft_protocol::mint_cap::MintCap;
    use nft_protocol::royalty_strategy_bps;
    use nft_protocol::tags;
    use nft_protocol::symbol::{Self};

    use ob_launchpad::inventory::{Self};
    use ob_launchpad::listing::{Self, Listing};

    use ob_permissions::witness;
    use liquidity_layer::orderbook::{Self};
    use ob_request::transfer_request::{Self};
    use ob_request::withdraw_request::{Self};

    /// One time witness is only instantiated in the init method
    struct MODULE_NAME has drop {}

    /// Can be used for authorization of other actions post-creation. It is
    /// vital that this struct is not freely given to any contract, because it
    /// serves as an auth token.
    struct Witness has drop {}

    struct ModuleName has key, store {
        id: UID,
        name: String,
        description: String,
        url: Url,
        attributes: Attributes,
    }

    struct MetadataStore has key, store {
        id: UID,
        name: vector<String>,
        description: vector<String>,
        url: vector<Url>,
        attributes: vector<Attributes>,
    }

    fun init(otw: MODULE_NAME, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        // Init Collection & MintCap with unlimited supply
        let (collection, mint_cap) = collection::create_with_mint_cap<MODULE_NAME, ModuleName>(
            &otw, option::none(), ctx
        );

        // Init Publisher
        let publisher = sui::package::claim(otw, ctx);

        let (transfer_policy, transfer_policy_cap) = transfer_request::init_policy<ModuleName>(&publisher, ctx);

        // Init Display
        let display = display::new<ModuleName>(&publisher, ctx);
        display::add(&mut display, string::utf8(b"name"), string::utf8(b"{name}"));
        display::add(&mut display, string::utf8(b"description"), string::utf8(b"{description}"));
        display::add(&mut display, string::utf8(b"image_url"), string::utf8(b"{url}"));
        display::add(&mut display, string::utf8(b"attributes"), string::utf8(b"{attributes}"));
        display::update_version(&mut display);
        transfer::public_transfer(display, tx_context::sender(ctx));

        // Get the Delegated Witness
        let dw = witness::from_witness(Witness {});

        // Add name and description to Collection
        collection::add_domain(dw, &mut collection, display_info::new( string::utf8(b"{{ name }}"), string::utf8(b"{{ description }}")));
        collection::add_domain(dw, &mut collection, symbol::new(string::utf8(b"{{ symbol }}")));
        //collection::add_domain(dw, &mut collection, display_url::new(string::utf8(b"{{ url }}")));

        // Creators domain
        collection::add_domain(
            dw,
            &mut collection,
            creators::new(vec_set::singleton(sender)),
        );

       let (withdraw_policy, withdraw_policy_cap) =  withdraw_request::init_policy<ModuleName>(
           &publisher, 
           ctx
        );

        // Royalties
        royalty_strategy_bps::create_domain_and_add_strategy(
            dw, &mut collection, 100, ctx,
        );

        // Enforce Royalty
        royalty_strategy_bps::enforce(&mut transfer_policy, &transfer_policy_cap);

        // Tags
        let tags = vector[tags::art()];
        collection::add_domain(dw, &mut collection, tags);

        let listing = listing::new(
            tx_context::sender(ctx),
            tx_context::sender(ctx),
            ctx,
        );

        let inventory_id = listing::create_warehouse<ModuleName>(
            &mut listing, ctx
        );

        ob_launchpad::fixed_price::init_venue<ModuleName, sui::sui::SUI>(
            &mut listing,
            inventory_id,
            false, // is whitelisted
            500, // price
            ctx,
        );

        orderbook::create_unprotected<ModuleName, sui::sui::SUI>(
            dw,
            &transfer_policy, 
            ctx
        );

        transfer::public_transfer(publisher, sender);
        transfer::public_transfer(mint_cap, sender);
        transfer::public_transfer(transfer_policy_cap, sender);
        transfer::public_transfer(withdraw_policy_cap, tx_context::sender(ctx));
        transfer::public_share_object(listing);
        transfer::public_share_object(collection);
        transfer::public_share_object(transfer_policy);
        transfer::public_share_object(withdraw_policy);
    }

    public entry fun mint_nft(
        name: String,
        description: String,
        url: vector<u8>,
        attribute_keys: vector<ascii::String>,
        attribute_values: vector<ascii::String>,
        mint_cap: &MintCap<ModuleName>,
        listing: &mut Listing,
        inventory_id: ID,
        ctx: &mut TxContext,
    ) {
        let nft = ModuleName {
            id: object::new(ctx),
            name,
            description,
            url: url::new_unsafe_from_bytes(url),
            attributes: attributes::from_vec(attribute_keys, attribute_values)
        };

        mint_event::emit_mint(
            witness::from_witness(Witness {}),
            mint_cap::collection_id(mint_cap),
            &nft
        );

        let inventory = listing::inventory_admin_mut<ModuleName>(listing, inventory_id, ctx);
        inventory::deposit_nft(inventory, nft);
    }

    public entry fun mint_nft_to_wallet(
        name: String,
        description: String,
        url: vector<u8>,
        attribute_keys: vector<ascii::String>,
        attribute_values: vector<ascii::String>,
        mint_cap: &MintCap<ModuleName>,
        wallet: address,
        ctx: &mut TxContext,
    ) {
        let nft = ModuleName {
            id: object::new(ctx),
            name,
            description,
            url: url::new_unsafe_from_bytes(url),
            attributes: attributes::from_vec(attribute_keys, attribute_values)
        };

        mint_event::emit_mint(
            witness::from_witness(Witness {}),
            mint_cap::collection_id(mint_cap),
            &nft
        );

        transfer::public_transfer(nft, wallet);
    }

    // Call by Collection owner
    public entry fun create_metadata_store(
        publisher: &Publisher,
        ctx: &mut TxContext,
    ) {
        assert!(package::from_package<ModuleName>(publisher), 1);

        let metadata_store = MetadataStore {
            id: object::new(ctx),
            name: vector::empty(),
            description: vector::empty(),
            url: vector::empty(),
            attributes: vector::empty(),
        };

        transfer::share_object(metadata_store);
    }

    // Call by Collection owner
    public entry fun insert_nft_metadata(
        publisher: &Publisher,
        metadataStore: &mut MetadataStore,
        name: String,
        description: String,
        url: vector<u8>,
        attribute_keys: vector<ascii::String>,
        attribute_values: vector<ascii::String>,
        _ctx: &mut TxContext,
    ) {
        assert!(package::from_package<ModuleName>(publisher), 1);
        vector::push_back(&mut metadataStore.name, name);
        vector::push_back(&mut metadataStore.description, description);
        vector::push_back(&mut metadataStore.url, url::new_unsafe_from_bytes(url));
        vector::push_back(&mut metadataStore.attributes, attributes::from_vec(attribute_keys, attribute_values));
    }

    // Call by NFT owner
    public entry fun reveal_nft(
        nft: &mut ModuleName,
        metadataStore: &mut MetadataStore,
        _ctx: &mut TxContext,
    ) {
        let name = vector::pop_back<String>(&mut metadataStore.name);
        let description = vector::pop_back<String>(&mut metadataStore.description);
        if (!string::is_empty(&name)) {
            nft.name = name;
        };
        if (!string::is_empty(&description)) {
            nft.description = description;
        };
        nft.url = vector::pop_back<Url>(&mut metadataStore.url);
        nft.attributes = vector::pop_back<Attributes>(&mut metadataStore.attributes);
    }
}
