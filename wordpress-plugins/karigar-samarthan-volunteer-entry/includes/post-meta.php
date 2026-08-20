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
 * Volunteer-submitted products auto-publish immediately, no admin approval
 * gate - a volunteer's work in the field shouldn't wait on someone else's
 * availability. _ks_needs_review / _ks_images_pending are informational
 * only (see admin-ui.php), they don't block anything.
 */
