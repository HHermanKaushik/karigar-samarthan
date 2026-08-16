<?php
if (!defined('ABSPATH')) exit;

/**
 * Handle volunteer photo uploads for Karigar products
 */

add_action('admin_post_ks_upload_photos', 'ks_handle_photo_upload');

function ks_handle_photo_upload() {

    // Security: logged-in users only
    if (!is_user_logged_in()) {
        wp_die('Unauthorized');
    }

    $user = wp_get_current_user();

    if (
        !in_array('ks_volunteer', (array) $user->roles, true) &&
        !current_user_can('administrator')
    ) {
        wp_die('Unauthorized');
    }

    check_admin_referer('ks_photo_upload');

    if (empty($_POST['product_id']) || empty($_FILES['ks_photos'])) {
        wp_die('Missing data');
    }

    $product_id = intval($_POST['product_id']);

    if (get_post_type($product_id) !== 'product') {
        wp_die('Invalid product');
    }

    require_once ABSPATH . 'wp-admin/includes/file.php';
    require_once ABSPATH . 'wp-admin/includes/media.php';
    require_once ABSPATH . 'wp-admin/includes/image.php';

    $attachment_ids = [];

    // Read the multi-file upload into a plain local copy first. The loop
    // below used to overwrite the entire $_FILES superglobal on every
    // iteration (`$_FILES = ['upload_file' => $file]`), which worked for
    // the first photo but destroyed $_FILES['ks_photos'] for every photo
    // after it - each subsequent iteration then read from a superglobal
    // that no longer had the data it needed, silently failing. Iterating
    // over this local copy instead means nothing the loop does to $_FILES
    // can affect what the next iteration reads.
    $uploaded_files = $_FILES['ks_photos'];

    foreach ($uploaded_files['name'] as $key => $value) {

        if ($uploaded_files['error'][$key] !== UPLOAD_ERR_OK) {
            continue;
        }

        // A unique key per file, added to (not replacing) $_FILES, so
        // concurrent/subsequent iterations are unaffected.
        $file_key = 'ks_upload_' . $key;

        $_FILES[$file_key] = [
            'name'     => $uploaded_files['name'][$key],
            'type'     => $uploaded_files['type'][$key],
            'tmp_name' => $uploaded_files['tmp_name'][$key],
            'error'    => $uploaded_files['error'][$key],
            'size'     => $uploaded_files['size'][$key],
        ];

        $attachment_id = media_handle_upload($file_key, $product_id);

        unset($_FILES[$file_key]);

        if (!is_wp_error($attachment_id)) {
            $attachment_ids[] = $attachment_id;
        }
    }

    if (!empty($attachment_ids)) {

        // Set featured image if none exists
        if (!has_post_thumbnail($product_id)) {
            set_post_thumbnail($product_id, $attachment_ids[0]);
        }

        // Add to product gallery
        $existing_gallery = get_post_meta($product_id, '_product_image_gallery', true);
        $existing_ids = $existing_gallery ? explode(',', $existing_gallery) : [];
        $all_ids = array_merge($existing_ids, $attachment_ids);

        update_post_meta($product_id, '_product_image_gallery', implode(',', $all_ids));

        // Clear images pending flag
        update_post_meta($product_id, '_ks_images_pending', 'no');
    }

    $redirect = wp_get_referer() ?: home_url('/');
    wp_safe_redirect(add_query_arg('photos_uploaded', '1', $redirect));
    exit;
}
