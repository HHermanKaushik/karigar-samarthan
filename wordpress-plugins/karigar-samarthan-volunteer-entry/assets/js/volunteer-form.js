jQuery(function ($) {
    const entryForm = $('form.ks-volunteer-form');
    const DRAFT_KEY = 'ks_volunteer_draft';

    // A successful submit reloads this same page with ?ks_success=1 and
    // shows this same form again, blank, for the next karigar. Without
    // this check, the leftover draft from the karigar who was JUST
    // submitted would silently pre-fill into the next person's entry.
    const justSucceeded = new URLSearchParams(window.location.search).get('ks_success') === '1';

    if (justSucceeded) {
        localStorage.removeItem(DRAFT_KEY);
    } else {
        const saved = localStorage.getItem(DRAFT_KEY);
        if (saved) {
            JSON.parse(saved).forEach(field => {
                entryForm.find(`[name="${field.name}"]`).val(field.value);
            });
        }
    }

    entryForm.on('change', 'input', function () {
        const data = entryForm.serializeArray();
        localStorage.setItem(DRAFT_KEY, JSON.stringify(data));
    });

    // Both volunteer forms embed a security token when the page first
    // renders, valid only for a limited window or a single use. This tool
    // is meant to stay open through a long field day of patchy
    // connectivity, and the photo-upload step is explicitly "come back to
    // this later" by design - both are exactly the conditions that let
    // that token go stale before it's actually submitted, surfacing as
    // "The link you followed has expired." Fetching a live token right at
    // submit time avoids that regardless of how long the page sat open.
    function refreshNonceAndSubmit(form, nonceKey) {
        $.post(ksVolunteer.ajaxUrl, { action: 'ks_refresh_nonce' })
            .done(function (response) {
                if (response && response.success && response.data && response.data[nonceKey]) {
                    form.find('[name="_wpnonce"]').val(response.data[nonceKey]);
                }
            })
            .always(function () {
                // Submit either way - if the refresh call itself failed
                // (e.g. no connection right this second), fall back to
                // whatever token was already on the page rather than
                // blocking the volunteer from even trying.
                form.off('submit.ksNonceRefresh').trigger('submit');
            });
    }

    $('form.ks-volunteer-form, form.ks-photo-upload-form').each(function () {
        const form = $(this);
        const nonceKey = form.hasClass('ks-photo-upload-form')
            ? 'ks_photo_upload_nonce'
            : 'ks_volunteer_submit_nonce';

        form.on('submit.ksNonceRefresh', function (e) {
            e.preventDefault();
            refreshNonceAndSubmit(form, nonceKey);
        });
    });
});
