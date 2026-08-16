<?php
/**
 * Plugin Name: Karigar Samarthan – Volunteer Entry
 * Description: Volunteer-operated fallback system for creating Karigar products in low-connectivity environments.
 * Version: 2.1.5
 * Author: Karigar Samarthan / JS Trust
 */

if (!defined('ABSPATH')) exit;
error_reporting(E_ALL);
ini_set('display_errors', 1);

define('KS_VOLUNTEER_MODE', true);
define('KS_PLUGIN_PATH', plugin_dir_path(__FILE__));
define('KS_PLUGIN_URL', plugin_dir_url(__FILE__));

require_once KS_PLUGIN_PATH . 'includes/roles.php';
require_once KS_PLUGIN_PATH . 'includes/post-meta.php';
require_once KS_PLUGIN_PATH . 'includes/volunteer-mode.php';
require_once KS_PLUGIN_PATH . 'includes/product-handler.php';
require_once KS_PLUGIN_PATH . 'includes/admin-ui.php';
require_once KS_PLUGIN_PATH . 'includes/shortcode.php';
require_once KS_PLUGIN_PATH . 'includes/photo-handler.php';


add_action('init', 'ks_register_assets');
function ks_register_assets() {
    wp_register_script(
        'ks-volunteer-js',
        KS_PLUGIN_URL . 'assets/js/volunteer-form.js',
        ['jquery'],
        '2.1',
        true
    );

    // Lets volunteer-form.js reach admin-ajax.php to pull a fresh nonce
    // right before submitting, instead of trusting whatever was baked
    // into the page whenever it first loaded - see ks_refresh_nonce()
    // below for why that matters for this specific tool.
    wp_localize_script('ks-volunteer-js', 'ksVolunteer', [
        'ajaxUrl' => admin_url('admin-ajax.php'),
    ]);

    wp_register_style(
        'ks-volunteer-css',
        KS_PLUGIN_URL . 'assets/css/volunteer.css',
        [],
        '2.0'
    );
}

/**
 * Issues fresh security tokens for both volunteer forms (product creation
 * and photo upload) on request. The token WordPress bakes into a form when
 * it first renders is only valid for a limited window (WordPress's default
 * is roughly half a day) or until used once - but this tool is meant to sit
 * open through a long field day in patchy connectivity, and the photo
 * upload step is explicitly designed to happen "later" per the form's own
 * copy. Both are exactly the conditions that make the baked-in token go
 * stale before it's actually used, which surfaces to the volunteer as
 * "The link you followed has expired." Fetching a live one at the moment
 * of submit sidesteps that regardless of how long the page has been open.
 *
 * wp_ajax_ (not wp_ajax_nopriv_) means WordPress already returns a generic
 * failure to logged-out requests before this function ever runs; the
 * explicit checks below are a second, more specific layer on top of that.
 */
add_action('wp_ajax_ks_refresh_nonce', 'ks_refresh_nonce');
function ks_refresh_nonce() {
    if (!is_user_logged_in()) {
        wp_send_json_error('unauthorized', 401);
    }

    $user = wp_get_current_user();
    if (
        !in_array('ks_volunteer', (array) $user->roles, true) &&
        !current_user_can('administrator')
    ) {
        wp_send_json_error('unauthorized', 403);
    }

    wp_send_json_success([
        'ks_volunteer_submit_nonce' => wp_create_nonce('ks_volunteer_submit'),
        'ks_photo_upload_nonce'     => wp_create_nonce('ks_photo_upload'),
    ]);
}
