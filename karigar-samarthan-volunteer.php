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
        '2.0',
        true
    );

    wp_register_style(
        'ks-volunteer-css',
        KS_PLUGIN_URL . 'assets/css/volunteer.css',
        [],
        '2.0'
    );
}
