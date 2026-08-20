<?php
if (!defined('ABSPATH')) exit;

/**
 * [ks_camp_entry] - the offline-capable camp entry flow. Separate tag
 * from Volunteer Entry's [ks_volunteer_form] - meant to run side by side.
 */
add_shortcode('ks_camp_entry', 'kscamp_render_shortcode');

function kscamp_render_shortcode($atts) {
    if (!is_user_logged_in()) {
        return '<p class="kscamp-error">Please log in as a volunteer to start a camp session.</p>';
    }

    if (!kscamp_user_is_authorized()) {
        return '<p class="kscamp-error">Your account is not set up as a volunteer.</p>';
    }

    wp_enqueue_style('kscamp-camp-session-css');
    wp_enqueue_script('kscamp-offline-db');
    wp_enqueue_script('kscamp-sync-engine');
    wp_enqueue_script('kscamp-camp-session');

    wp_localize_script('kscamp-camp-session', 'ksCampSession', [
        'ajaxUrl' => admin_url('admin-ajax.php'),
    ]);

    ob_start();
    ?>
    <div id="kscamp-root" class="kscamp-root">
        <noscript>
            <p class="kscamp-error">
                This tool needs JavaScript enabled to work offline through the day - please use the
                regular entry form instead if JavaScript can't be turned on for this device.
            </p>
        </noscript>
        <p class="kscamp-loading">Loading camp session…</p>
    </div>
    <?php
    return ob_get_clean();
}
