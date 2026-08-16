<?php
if (!defined('ABSPATH')) exit;

/**
 * Handle volunteer product creation
 * Runs ONLY on form submission via admin-post.php
 */

add_action('admin_post_ks_create_product', 'ks_handle_product_create');

function ks_handle_product_create() {

    // 1. Hard stop if not logged in
    if (!is_user_logged_in()) {
        wp_die('Unauthorized');
    }

    $user = wp_get_current_user();

    // 2. Role check (volunteer OR admin)
    if (
        !in_array('ks_volunteer', (array) $user->roles, true) &&
        !current_user_can('administrator')
    ) {
        wp_die('Unauthorized');
    }

    // 3. Nonce check
    check_admin_referer('ks_volunteer_submit');

    // 4. Required fields validation
    if (
        empty($_POST['product_name']) ||
        empty($_POST['price']) ||
        empty($_POST['karigar_name']) ||
        empty($_POST['craft'])
    ) {
        wp_die('Missing required fields');
    }

    // 5. Create product post (AUTO-PUBLISH by design - volunteer entries
    //    are never held for approval, see post-meta.php)
    $product_id = wp_insert_post([
        'post_title'  => sanitize_text_field($_POST['product_name']),
        'post_type'   => 'product',
        'post_status' => 'publish',
    ]);

    if (is_wp_error($product_id) || !$product_id) {
        wp_die('Failed to create product');
    }

    // 6. Pricing (WooCommerce-safe meta usage)
    $price = floatval($_POST['price']);
    update_post_meta($product_id, '_regular_price', $price);
    update_post_meta($product_id, '_price', $price);

    // 7. Karigar snapshot (immutable record)
    update_post_meta($product_id, '_ks_karigar_name', sanitize_text_field($_POST['karigar_name']));
    update_post_meta($product_id, '_ks_karigar_village', sanitize_text_field($_POST['village'] ?? ''));
    update_post_meta($product_id, '_ks_karigar_craft', sanitize_text_field($_POST['craft']));
    update_post_meta($product_id, '_ks_consent_collected', 'yes');

    // 8. Volunteer attribution
    update_post_meta($product_id, '_ks_entry_mode', 'volunteer');
    update_post_meta($product_id, '_ks_entered_by_volunteer', get_current_user_id());
    update_post_meta($product_id, '_ks_entry_location', sanitize_text_field($_POST['location'] ?? ''));
    update_post_meta($product_id, '_ks_camp_id', sanitize_text_field($_POST['camp_id'] ?? ''));
    update_post_meta($product_id, '_ks_drive_name', sanitize_text_field($_POST['drive_name'] ?? ''));

    // 9. Operational flags (informational only - see post-meta.php)
    update_post_meta($product_id, '_ks_needs_review', 'yes');
    update_post_meta($product_id, '_ks_images_pending', 'yes');

    // 10. Redirect back to form with success flag
    $redirect = wp_get_referer();
    if (!$redirect) {
        $redirect = home_url('/');
    }

    wp_safe_redirect(add_query_arg([
        'ks_success' => '1',
        'product_id' => $product_id
    ], $redirect));
        exit;
}
