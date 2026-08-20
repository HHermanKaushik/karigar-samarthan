jQuery(function ($) {
    const entryForm = $('form.ks-volunteer-form');
    const DRAFT_KEY = 'ks_volunteer_draft';

    // Clear the draft on a successful submit (?ks_success=1), or it
    // pre-fills into the next karigar's blank form.
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

    // The page's baked-in nonce can go stale before submit, since this
    // form stays open through a long field day - fetch a live one instead.
    function refreshNonceAndSubmit(form, nonceKey) {
        $.post(ksVolunteer.ajaxUrl, { action: 'ks_refresh_nonce' })
            .done(function (response) {
                if (response && response.success && response.data && response.data[nonceKey]) {
                    form.find('[name="_wpnonce"]').val(response.data[nonceKey]);
                }
            })
            .always(function () {
                // Submit either way - fall back to the page's own token
                // if the refresh call failed.
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
