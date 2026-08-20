<?php
/**
 * Plugin Name: Karigar Samarthan — Brand Logo Shortcode
 * Description: Renders a seller banner (photo, karigar name, shop name, category filter) on WooCommerce Brand archive pages, plus a [ks_brand_logo] shortcode for manual placement. Repoints the "Home" breadcrumb on Brand pages to the shop page.
 * Version: 1.3.0
 * Author: J.S. Trust
 */

if (!defined('ABSPATH')) {
    exit; // No direct access.
}

/**
 * The karigar's own name, read from _ks_karigar_name product meta (no
 * equivalent field exists on the Brand term itself). Returns '' if the
 * brand has no products yet.
 */
function ks_get_karigar_name($brand_term_id) {
    $product_ids = get_posts([
        'post_type'      => 'product',
        'posts_per_page' => 1,
        'fields'         => 'ids',
        'tax_query'      => [[
            'taxonomy' => 'product_brand',
            'field'    => 'term_id',
            'terms'    => $brand_term_id,
        ]],
    ]);
    if (empty($product_ids)) {
        return '';
    }
    return (string) get_post_meta($product_ids[0], '_ks_karigar_name', true);
}

/**
 * Categories actually used by this seller's own products, not the site's
 * full list. Loops the seller's products directly rather than one clever
 * query - catalogs here are small enough that this stays simple.
 */
function ks_get_brand_categories($brand_term_id) {
    $product_ids = get_posts([
        'post_type'      => 'product',
        'posts_per_page' => -1,
        'fields'         => 'ids',
        'tax_query'      => [[
            'taxonomy' => 'product_brand',
            'field'    => 'term_id',
            'terms'    => $brand_term_id,
        ]],
    ]);

    $categories = []; // keyed by term_id to de-duplicate
    foreach ($product_ids as $product_id) {
        $terms = wp_get_post_terms($product_id, 'product_cat');
        foreach ($terms as $term) {
            $categories[$term->term_id] = $term;
        }
    }
    usort($categories, fn($a, $b) => strcasecmp($a->name, $b->name));
    return array_values($categories);
}

/**
 * Full seller banner: photo, karigar name, shop name, and the "All /
 * Category / Category" filter row. Returns '' outside a Brand archive page
 * so it's safe to call unconditionally from the hook or the shortcode.
 */
function ks_brand_banner_html() {
    if (!is_tax('product_brand')) {
        return '';
    }

    $term = get_queried_object();
    if (!$term || is_wp_error($term)) {
        return '';
    }

    $thumbnail_id = get_term_meta($term->term_id, 'thumbnail_id', true);
    $photo_html = $thumbnail_id
        ? wp_get_attachment_image($thumbnail_id, 'medium', false, ['class' => 'ks-banner-photo', 'alt' => esc_attr($term->name)])
        : '<div class="ks-banner-photo ks-banner-photo-placeholder"></div>';

    $karigar_name = ks_get_karigar_name($term->term_id);
    $categories = ks_get_brand_categories($term->term_id);
    $brand_url = get_term_link($term);
    $active_cat = is_string($_GET['ks_cat'] ?? null) ? sanitize_title(wp_unslash($_GET['ks_cat'])) : '';

    ob_start();
    ?>
    <div class="ks-brand-banner">
        <div class="ks-banner-top">
            <?php echo $photo_html; ?>
            <div class="ks-banner-text">
                <p class="ks-banner-shop"><?php echo esc_html($term->name); ?></p>
                <?php if ($karigar_name) : ?>
                    <p class="ks-banner-karigar">by <?php echo esc_html($karigar_name); ?></p>
                <?php endif; ?>
            </div>
        </div>
        <?php if (!empty($categories)) : ?>
            <nav class="ks-banner-filters" aria-label="Filter by category">
                <a href="<?php echo esc_url(is_wp_error($brand_url) ? '' : $brand_url); ?>"
                   class="ks-filter-pill<?php echo $active_cat === '' ? ' is-active' : ''; ?>">All</a>
                <?php foreach ($categories as $cat) :
                    $filter_url = add_query_arg('ks_cat', $cat->slug, is_wp_error($brand_url) ? '' : $brand_url);
                ?>
                    <a href="<?php echo esc_url($filter_url); ?>"
                       class="ks-filter-pill<?php echo $active_cat === $cat->slug ? ' is-active' : ''; ?>"><?php echo esc_html($cat->name); ?></a>
                <?php endforeach; ?>
            </nav>
        <?php endif; ?>
    </div>
    <?php
    return ob_get_clean();
}

// Manual placement: drop [ks_brand_logo] anywhere shortcodes render.
add_shortcode('ks_brand_logo', 'ks_brand_banner_html');

// Automatic placement: fires near the top of every WooCommerce archive
// page, regardless of theme or page builder. No template file to edit.
add_action('woocommerce_before_shop_loop', 'ks_brand_banner_print', 5);
function ks_brand_banner_print() {
    echo ks_brand_banner_html();
}

/**
 * Applies the "ks_cat" filter pill to the product query, ANDed with the
 * existing brand restriction so a category pill narrows this seller's
 * products, not the whole site's.
 */
add_action('pre_get_posts', 'ks_apply_brand_category_filter');
function ks_apply_brand_category_filter($query) {
    if (is_admin() || !$query->is_main_query()) {
        return;
    }
    if (!is_tax('product_brand') || !is_string($_GET['ks_cat'] ?? null) || $_GET['ks_cat'] === '') {
        return;
    }

    $tax_query = $query->get('tax_query') ?: [];
    $tax_query[] = [
        'taxonomy' => 'product_cat',
        'field'    => 'slug',
        'terms'    => sanitize_title(wp_unslash($_GET['ks_cat'])),
    ];
    $tax_query['relation'] = 'AND';
    $query->set('tax_query', $tax_query);
}

// Banner styling, enqueued only on Brand archive pages. clamp() handles
// scaling on narrow screens without separate breakpoints.
add_action('wp_head', 'ks_brand_banner_styles');
function ks_brand_banner_styles() {
    if (!is_tax('product_brand')) {
        return;
    }
    ?>
    <style>
        .ks-brand-banner {
            max-width: 640px;
            margin: 0 auto 28px;
            padding: 0 16px;
        }
        .ks-banner-top {
            display: flex;
            align-items: center;
            gap: clamp(12px, 4vw, 20px);
            flex-wrap: wrap;
            justify-content: center;
            text-align: left;
        }
        .ks-banner-photo,
        .ks-banner-photo-placeholder {
            width: clamp(90px, 20vw, 160px);
            height: clamp(90px, 20vw, 160px);
            border-radius: 50%;
            object-fit: cover;
            flex: none;
            border: 2px solid rgba(0, 0, 0, 0.08);
            background: #f0f0f0;
        }
        .ks-banner-text {
            min-width: 0;
        }
        .ks-banner-shop {
            margin: 0;
            font-size: clamp(20px, 4vw, 28px);
            font-weight: 700;
            line-height: 1.2;
        }
        .ks-banner-karigar {
            margin: 4px 0 0;
            font-size: clamp(13px, 2.5vw, 15px);
            color: rgba(0, 0, 0, 0.6);
        }
        .ks-banner-filters {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            justify-content: center;
            margin-top: 18px;
        }
        .ks-filter-pill {
            display: inline-block;
            padding: 6px 14px;
            border-radius: 999px;
            border: 1px solid rgba(0, 0, 0, 0.15);
            font-size: 13px;
            text-decoration: none;
            color: inherit;
            transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
        }
        .ks-filter-pill:hover {
            border-color: rgba(0, 0, 0, 0.35);
        }
        .ks-filter-pill.is-active {
            background: #1b1b1b;
            border-color: #1b1b1b;
            color: #fff;
        }
        @media (prefers-color-scheme: dark) {
            .ks-banner-karigar { color: rgba(255, 255, 255, 0.65); }
            .ks-filter-pill { border-color: rgba(255, 255, 255, 0.25); }
            .ks-filter-pill.is-active { background: #fff; border-color: #fff; color: #1b1b1b; }
        }
    </style>
    <?php
}

/**
 * Repoints the breadcrumb's "Home" link on Brand pages to the shop page.
 * Done in JS, not a PHP filter, since the breadcrumb markup could come
 * from WooCommerce core, Elementor, or a Yoast-style plugin depending on
 * theme - matching rendered text is reliable regardless of source. Scoped
 * to "breadcrumb"-class elements with link text exactly "Home" so it
 * can't touch an unrelated link (e.g. the site logo).
 */
add_action('wp_footer', 'ks_fix_brand_breadcrumb_home_link');
function ks_fix_brand_breadcrumb_home_link() {
    if (!is_tax('product_brand')) {
        return;
    }
    $target_url = home_url('/karigar-samarthan/');
    ?>
    <script>
    document.addEventListener('DOMContentLoaded', function () {
        var target = <?php echo wp_json_encode($target_url); ?>;
        document.querySelectorAll('[class*="breadcrumb"] a').forEach(function (link) {
            if (link.textContent.trim().toLowerCase() === 'home') {
                link.setAttribute('href', target);
            }
        });
    });
    </script>
    <?php
}
