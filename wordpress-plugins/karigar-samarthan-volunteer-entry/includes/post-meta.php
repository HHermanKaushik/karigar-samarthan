<?php
/**
 * Post meta and lifecycle definitions for Karigar Samarthan – Volunteer Entry
 */

if (!defined('ABSPATH')) exit;

/**
 * Register custom meta fields for volunteer-created products
 */
add_action('init', function () {

    // Entry mode: volunteer / normal
    register_post_meta('product', '_ks_entry_mode', [
        'type'              => 'string',
        'single'            => true,
        'show_in_rest'      => true,
        'sanitize_callback' => 'sanitize_text_field',
    ]);

    // Photo workflow status: pending | uploaded | approved
    register_post_meta('product', '_ks_photo_status', [
        'type'              => 'string',
        'single'            => true,
        'show_in_rest'      => true,
        'sanitize_callback' => 'sanitize_text_field',
    ]);

    // Volunteer who created the product
    register_post_meta('product', '_ks_created_by_volunteer', [
        'type'              => 'integer',
        'single'            => true,
        'show_in_rest'      => true,
        'sanitize_callback' => 'absint',
    ]);

    // Snapshot metadata (non-editable by karigar)
    register_post_meta('product', '_ks_karigar_name', [
        'type' => 'string',
        'single' => true,
        'show_in_rest' => true,
        'sanitize_callback' => 'sanitize_text_field',
    ]);

    register_post_meta('product', '_ks_karigar_village', [
        'type' => 'string',
        'single' => true,
        'show_in_rest' => true,
        'sanitize_callback' => 'sanitize_text_field',
    ]);

    register_post_meta('product', '_ks_karigar_craft', [
        'type' => 'string',
        'single' => true,
        'show_in_rest' => true,
        'sanitize_callback' => 'sanitize_text_field',
    ]);

});

/**
 * Utility: check if a product is a volunteer fallback product
 */
function ks_is_volunteer_product($product_id) {
    return get_post_meta($product_id, '_ks_entry_mode', true) === 'volunteer';
}

/**
 * Utility: check if photos are still pending
 */
function ks_product_photos_pending($product_id) {
    return get_post_meta($product_id, '_ks_photo_status', true) === 'pending';
}

/**
 * Volunteer-submitted products auto-publish immediately and do NOT require
 * admin approval before going live - by design, so a volunteer's work in
 * the field is never blocked on someone else's availability. This was
 * previously enforced as a hard wp_die() gate on publish, but that gate
 * never actually fired (it checked _ks_entry_mode, which product-handler.php
 * never set, so ks_is_volunteer_product() was always false) - removed
 * outright rather than "fixed", since a working gate is not what's wanted
 * here. _ks_needs_review / _ks_images_pending remain as informational flags
 * only, surfaced in the admin Products list (see admin-ui.php) so staff can
 * see which live listings still need photos - they no longer block anything.
 */
