<?php
/**
 * Plugin Name: Karigar Samarthan – Camp Session (Offline Entry)
 * Description: Offline-capable camp entry tool - capture a karigar once, add unlimited products with photos on-device, sync automatically when connected. Independent of "Karigar Samarthan – Volunteer Entry".
 * Version: 1.0.0
 * Author: Karigar Samarthan / JS Trust
 */

if (!defined('ABSPATH')) exit;

define('KSCAMP_PLUGIN_PATH', plugin_dir_path(__FILE__));
define('KSCAMP_PLUGIN_URL', plugin_dir_url(__FILE__));

require_once KSCAMP_PLUGIN_PATH . 'includes/product-sync.php';
require_once KSCAMP_PLUGIN_PATH . 'includes/shortcode.php';

/**
 * Gated on the same 'ks_volunteer' role Volunteer Entry uses, so the same
 * accounts work in both tools. Doesn't create the role itself - falls
 * back to administrators only if it's missing.
 */
function kscamp_user_is_authorized(): bool {
    if (!is_user_logged_in()) return false;
    $user = wp_get_current_user();
    return in_array('ks_volunteer', (array) $user->roles, true) || current_user_can('administrator');
}

add_action('init', 'kscamp_register_assets');
function kscamp_register_assets() {
    wp_register_script('kscamp-offline-db', KSCAMP_PLUGIN_URL . 'assets/js/ks-offline-db.js', [], '1.0', true);
    wp_register_script('kscamp-sync-engine', KSCAMP_PLUGIN_URL . 'assets/js/ks-sync-engine.js', ['kscamp-offline-db'], '1.0', true);
    wp_register_script('kscamp-camp-session', KSCAMP_PLUGIN_URL . 'assets/js/ks-camp-session.js', ['kscamp-offline-db', 'kscamp-sync-engine'], '1.0', true);
    wp_register_style('kscamp-camp-session-css', KSCAMP_PLUGIN_URL . 'assets/css/ks-camp-session.css', [], '1.0');
}

/**
 * Issues fresh nonces on request - a camp session stays open through a
 * multi-hour field day, which outlives a nonce's normal validity window.
 * Own action names, no dependency on Volunteer Entry's endpoint.
 */
add_action('wp_ajax_kscamp_refresh_nonce', 'kscamp_ajax_refresh_nonce');
function kscamp_ajax_refresh_nonce() {
    if (!kscamp_user_is_authorized()) {
        wp_send_json_error(['message' => 'unauthorized'], 401);
    }

    wp_send_json_success([
        'kscamp_submit_nonce' => wp_create_nonce('kscamp_submit'),
        'kscamp_photo_nonce'  => wp_create_nonce('kscamp_photo_upload'),
    ]);
}
