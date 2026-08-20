<?php
if (!defined('ABSPATH')) exit;

/**
 * JSON/AJAX endpoints ks-sync-engine.js calls once connected. Self-
 * contained - doesn't call into the Volunteer Entry plugin. JSON, not a
 * redirect, since these are called from fetch() by a background loop.
 */

add_action('wp_ajax_kscamp_sync_product', 'kscamp_ajax_sync_product');
function kscamp_ajax_sync_product() {
    if (!kscamp_user_is_authorized()) {
        wp_send_json_error(['message' => 'unauthorized'], 401);
    }

    $nonce = $_POST['_wpnonce'] ?? '';
    if (!wp_verify_nonce($nonce, 'kscamp_submit')) {
        wp_send_json_error(['message' => 'expired_nonce'], 400);
    }

    $result = kscamp_create_product($_POST, get_current_user_id());

    if (is_wp_error($result)) {
        wp_send_json_error(['message' => $result->get_error_message()], 400);
    }

    wp_send_json_success(['product_id' => $result]);
}

add_action('wp_ajax_kscamp_sync_photos', 'kscamp_ajax_sync_photos');
function kscamp_ajax_sync_photos() {
    if (!kscamp_user_is_authorized()) {
        wp_send_json_error(['message' => 'unauthorized'], 401);
    }

    $nonce = $_POST['_wpnonce'] ?? '';
    if (!wp_verify_nonce($nonce, 'kscamp_photo_upload')) {
        wp_send_json_error(['message' => 'expired_nonce'], 400);
    }

    if (empty($_POST['product_id']) || empty($_FILES['kscamp_photos'])) {
        wp_send_json_error(['message' => 'missing_data'], 400);
    }

    $product_id = intval($_POST['product_id']);
    if (get_post_type($product_id) !== 'product') {
        wp_send_json_error(['message' => 'invalid_product'], 400);
    }

    $attachment_ids = kscamp_attach_photos($product_id, $_FILES['kscamp_photos']);

    wp_send_json_success(['attachment_ids' => $attachment_ids]);
}

/**
 * Creates one volunteer-submitted product, auto-published. [local_uuid]
 * makes this idempotent - a retry after a dropped connection returns the
 * existing product instead of duplicating it.
 *
 * @return int|WP_Error
 */
function kscamp_create_product(array $fields, int $volunteer_user_id) {

    if (
        empty($fields['product_name']) ||
        empty($fields['price']) ||
        empty($fields['karigar_name']) ||
        empty($fields['craft'])
    ) {
        return new WP_Error('kscamp_missing_fields', 'Missing required fields');
    }

    $local_uuid = isset($fields['local_uuid']) ? sanitize_text_field($fields['local_uuid']) : '';

    if ($local_uuid !== '') {
        $existing = kscamp_find_product_by_local_uuid($local_uuid);
        if ($existing) {
            return $existing;
        }
    }

    $product_id = wp_insert_post([
        'post_title'  => sanitize_text_field($fields['product_name']),
        'post_type'   => 'product',
        'post_status' => 'publish',
    ]);

    if (is_wp_error($product_id) || !$product_id) {
        return is_wp_error($product_id) ? $product_id : new WP_Error('kscamp_create_failed', 'Failed to create product');
    }

    $price = floatval($fields['price']);
    update_post_meta($product_id, '_regular_price', $price);
    update_post_meta($product_id, '_price', $price);

    update_post_meta($product_id, '_ks_karigar_name', sanitize_text_field($fields['karigar_name']));
    update_post_meta($product_id, '_ks_karigar_village', sanitize_text_field($fields['village'] ?? ''));
    update_post_meta($product_id, '_ks_karigar_craft', sanitize_text_field($fields['craft']));
    update_post_meta($product_id, '_ks_consent_collected', 'yes');

    // Same meta keys as Volunteer Entry so downstream reporting can't
    // tell which tool a listing came through.
    update_post_meta($product_id, '_ks_entry_mode', 'volunteer');
    update_post_meta($product_id, '_ks_entered_by_volunteer', $volunteer_user_id);
    update_post_meta($product_id, '_ks_entry_location', sanitize_text_field($fields['location'] ?? ''));
    update_post_meta($product_id, '_ks_camp_id', sanitize_text_field($fields['camp_id'] ?? ''));
    update_post_meta($product_id, '_ks_drive_name', sanitize_text_field($fields['drive_name'] ?? ''));

    update_post_meta($product_id, '_ks_needs_review', 'yes');
    update_post_meta($product_id, '_ks_images_pending', 'yes');

    if ($local_uuid !== '') {
        update_post_meta($product_id, '_kscamp_local_uuid', $local_uuid);
    }

    return $product_id;
}

function kscamp_find_product_by_local_uuid(string $local_uuid) {
    if ($local_uuid === '') {
        return null;
    }

    $posts = get_posts([
        'post_type'      => 'product',
        'post_status'    => 'any',
        'posts_per_page' => 1,
        'date_query'     => [['after' => '48 hours ago']],
        'meta_query'     => [[
            'key'   => '_kscamp_local_uuid',
            'value' => $local_uuid,
        ]],
        'fields' => 'ids',
    ]);

    return $posts ? (int) $posts[0] : null;
}

/**
 * Attaches an uploaded multi-file batch to a product: featured image if
 * none exists, appends to the gallery, clears the pending flag. Each
 * file gets a uniquely keyed $_FILES entry so every photo survives.
 *
 * @return int[] attachment IDs successfully attached
 */
function kscamp_attach_photos(int $product_id, array $uploaded_files): array {

    require_once ABSPATH . 'wp-admin/includes/file.php';
    require_once ABSPATH . 'wp-admin/includes/media.php';
    require_once ABSPATH . 'wp-admin/includes/image.php';

    $attachment_ids = [];

    foreach ($uploaded_files['name'] as $key => $value) {

        if ($uploaded_files['error'][$key] !== UPLOAD_ERR_OK) {
            continue;
        }

        $file_key = 'kscamp_upload_' . $key;

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
        if (!has_post_thumbnail($product_id)) {
            set_post_thumbnail($product_id, $attachment_ids[0]);
        }

        $existing_gallery = get_post_meta($product_id, '_product_image_gallery', true);
        $existing_ids = $existing_gallery ? explode(',', $existing_gallery) : [];
        $all_ids = array_merge($existing_ids, $attachment_ids);

        update_post_meta($product_id, '_product_image_gallery', implode(',', $all_ids));
        update_post_meta($product_id, '_ks_images_pending', 'no');
    }

    return $attachment_ids;
}
