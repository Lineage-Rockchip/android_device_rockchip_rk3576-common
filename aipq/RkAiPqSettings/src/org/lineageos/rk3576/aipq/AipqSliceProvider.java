package org.lineageos.rk3576.aipq;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import com.android.tv.twopanelsettings.slices.TvSettingsSliceProvider;
import com.android.tv.twopanelsettings.slices.builders.PreferenceSliceBuilder;
import com.android.tv.twopanelsettings.slices.builders.PreferenceSliceBuilder.RowBuilder;

/**
 * Hosts the AI PQ slice. The two-panel TvSettings opens it through
 * com.android.tv.twopanelsettings.slices.SliceFragment (the entry row is added
 * to the Device & sound page's Advanced display screen by the
 * TvSettingsAipqOverlay RRO) and renders the rows as native preferences:
 * addSwitch -> SliceSwitchPreference, addRadioButton -> SliceRadioPreference.
 *
 * Strengths are flat top-level radio rows, NOT category rows with children:
 * the category+children shape adds every child twice on the renderer side
 * (PreferenceGroup "duplicated key", logcat13 13:01:55) and breaks the radio
 * group. The in-tree producer to copy is ConnectedDevicesSliceProvider's
 * backlight radios -- one addPreference per option. Seekbars are still
 * avoided on purpose: the renderer's seekbar dispatch fires the row action
 * with only extra_preference_key filled in, no value and no direction
 * (SliceShard.onSeekbarPreferenceChanged), so a stateless provider cannot
 * learn the target value.
 */
public class AipqSliceProvider extends TvSettingsSliceProvider {

    public static final String AUTHORITY = "org.lineageos.rk3576.aipq";
    public static final Uri SLICE_URI =
            Uri.parse("content://" + AUTHORITY + "/main");
    public static final Uri DISPLAY_URI =
            Uri.parse("content://" + AUTHORITY + "/display");

    /** The renderer fills in this extra (SlicesConstants.EXTRA_PREFERENCE_KEY). */
    static final String EXTRA_PREFERENCE_KEY = "extra_preference_key";

    private static final int PAGE_ID = 990001; // TvSettingsEnums-namespace-free logging id

    @Override
    public boolean onCreateSliceProvider() {
        return true;
    }

    @Override
    public void onSlicePinned(Uri sliceUri) {
        // Same platform signature as TvSettings, so the slice is readable
        // already; grant explicitly anyway in case the signature policy is
        // ever tightened.
        try {
            getContext().getSystemService(android.app.slice.SliceManager.class)
                    .grantSlicePermission("com.android.tv.settings", sliceUri);
        } catch (Exception ignored) {
        }
    }

    @Override
    protected boolean createSlice(PreferenceSliceBuilder builder, Uri sliceUri) {
        if (DISPLAY_URI.equals(sliceUri)) {
            return createDisplaySlice(builder);
        }
        if (!SLICE_URI.equals(sliceUri)) {
            return false;
        }
        Context c = getContext();
        builder.addScreenTitle(new RowBuilder()
                .setTitle(c.getString(R.string.aipq_title))
                .setPageId(PAGE_ID));

        builder.addPreference(new RowBuilder()
                .setKey("aipq_master")
                .setTitle(c.getString(R.string.aipq_master_title))
                .setSubtitle(c.getString(R.string.aipq_master_summary))
                .addSwitch(knobIntent(c, AipqProps.KNOB_MASTER),
                        c.getString(R.string.aipq_master_title),
                        AipqProps.isMasterOn(c)));

        addStrengthGroup(builder, c, AipqProps.KNOB_SR,
                R.string.aipq_sr_title, R.string.aipq_sr_summary,
                AipqProps.srStrength(c));
        addStrengthGroup(builder, c, AipqProps.KNOB_DC,
                R.string.aipq_dc_title, R.string.aipq_dc_summary,
                AipqProps.dcStrength(c));
        addStrengthGroup(builder, c, AipqProps.KNOB_MEMC,
                R.string.aipq_memc_title, R.string.aipq_memc_summary,
                AipqProps.memcStrength(c));

        addSwitchRow(builder, c, AipqProps.KNOB_FE,
                R.string.aipq_fe_title, R.string.aipq_fe_summary,
                AipqProps.isFeOn(c));
        addSwitchRow(builder, c, AipqProps.KNOB_ACM,
                R.string.aipq_acm_title, R.string.aipq_acm_summary,
                AipqProps.isAcmOn(c));
        addSwitchRow(builder, c, AipqProps.KNOB_DCI,
                R.string.aipq_dci_title, R.string.aipq_dci_summary,
                AipqProps.isDciOn(c));
        addSwitchRow(builder, c, AipqProps.KNOB_SD,
                R.string.aipq_sd_title, R.string.aipq_sd_summary,
                AipqProps.isSdOn(c));

        addDemoGroup(builder, c);

        builder.addPreference(new RowBuilder()
                .setKey("aipq_note")
                .setTitle(c.getString(R.string.aipq_note))
                .setSelectable(false));
        return true;
    }

    /** Non-selectable header row + flat radio rows, backlight style. */
    private void addStrengthGroup(PreferenceSliceBuilder builder, Context c,
            String knob, int titleRes, int summaryRes, int current) {
        builder.addPreference(new RowBuilder()
                .setKey("aipq_" + knob + "_header")
                .setTitle(c.getString(titleRes))
                .setSubtitle(c.getString(summaryRes))
                .setSelectable(false));
        int[] labels = {R.string.aipq_strength_off, R.string.aipq_strength_low,
                R.string.aipq_strength_medium, R.string.aipq_strength_strong};
        for (int i = 0; i < AipqProps.STRENGTHS.length; i++) {
            int value = AipqProps.STRENGTHS[i];
            builder.addPreference(new RowBuilder()
                    .setKey("aipq_" + knob + "_" + value)
                    .setTitle(c.getString(labels[i]))
                    .setRadioGroup("aipq_" + knob)
                    .addRadioButton(
                            knobIntent(c, knob)
                                    .putExtra(AipqBroadcastReceiver.EXTRA_VALUE, value),
                            current == value));
        }
    }

    private void addDemoGroup(PreferenceSliceBuilder builder, Context c) {
        builder.addPreference(new RowBuilder()
                .setKey("aipq_demo_header")
                .setTitle(c.getString(R.string.aipq_demo_title))
                .setSubtitle(c.getString(R.string.aipq_demo_summary))
                .setSelectable(false));
        int[] labels = {R.string.aipq_strength_off, R.string.aipq_demo_on,
                R.string.aipq_demo_dynamic, R.string.aipq_demo_watermark};
        int current = AipqProps.demoMode(c);
        for (int i = 0; i < labels.length; i++) {
            builder.addPreference(new RowBuilder()
                    .setKey("aipq_demo_" + i)
                    .setTitle(c.getString(labels[i]))
                    .setRadioGroup("aipq_demo")
                    .addRadioButton(
                            knobIntent(c, AipqProps.KNOB_DEMO)
                                    .putExtra(AipqBroadcastReceiver.EXTRA_VALUE, i),
                            current == i));
        }
    }

    private void addSwitchRow(PreferenceSliceBuilder builder, Context c, String knob,
            int titleRes, int summaryRes, boolean checked) {
        String title = c.getString(titleRes);
        builder.addPreference(new RowBuilder()
                .setKey("aipq_" + knob)
                .setTitle(title)
                .setSubtitle(c.getString(summaryRes))
                .addSwitch(knobIntent(c, knob), title, checked));
    }

    private static Intent knobIntent(Context c, String knob) {
        Intent i = new Intent(AipqBroadcastReceiver.ACTION_KNOB);
        i.setClass(c, AipqBroadcastReceiver.class);
        i.putExtra(AipqBroadcastReceiver.EXTRA_KNOB, knob);
        return i;
    }

    /**
     * Display picture page: brightness/contrast/saturation/hue as percent
     * radios over the outputmanager HIDL. Steps of 10 -- the renderer's
     * seekbar dispatch is key-only (see the class comment), so radios are the
     * only stateless slider equivalent.
     */
    private boolean createDisplaySlice(PreferenceSliceBuilder builder) {
        Context c = getContext();
        builder.addScreenTitle(new RowBuilder()
                .setTitle(c.getString(R.string.disp_title))
                .setPageId(PAGE_ID + 1));
        int[] bcsh = RkOutputClient.nativeGetBcsh(RkOutputClient.DISPLAY_MAIN);
        if (bcsh == null) {
            bcsh = RkOutputClient.DEFAULT_BCSH;
            builder.addPreference(new RowBuilder()
                    .setKey("disp_unavailable")
                    .setTitle(c.getString(R.string.disp_unavailable))
                    .setSelectable(false));
        }
        addBcshGroup(builder, c, AipqProps.KNOB_BRIGHTNESS,
                R.string.disp_brightness, R.string.disp_brightness_summary, bcsh[0]);
        addBcshGroup(builder, c, AipqProps.KNOB_CONTRAST,
                R.string.disp_contrast, R.string.disp_contrast_summary, bcsh[1]);
        addBcshGroup(builder, c, AipqProps.KNOB_SATURATION,
                R.string.disp_saturation, R.string.disp_saturation_summary, bcsh[2]);
        addBcshGroup(builder, c, AipqProps.KNOB_HUE,
                R.string.disp_hue, R.string.disp_hue_summary, bcsh[3]);
        return true;
    }

    private void addBcshGroup(PreferenceSliceBuilder builder, Context c,
            String knob, int titleRes, int summaryRes, int current) {
        builder.addPreference(new RowBuilder()
                .setKey("disp_" + knob + "_header")
                .setTitle(c.getString(titleRes))
                .setSubtitle(c.getString(summaryRes))
                .setSelectable(false));
        for (int value = 0; value <= 100; value += 10) {
            builder.addPreference(new RowBuilder()
                    .setKey("disp_" + knob + "_" + value)
                    .setTitle(String.valueOf(value))
                    .setRadioGroup("disp_" + knob)
                    .addRadioButton(
                            knobIntent(c, knob)
                                    .putExtra(AipqBroadcastReceiver.EXTRA_VALUE, value),
                            current == value));
        }
    }
}
