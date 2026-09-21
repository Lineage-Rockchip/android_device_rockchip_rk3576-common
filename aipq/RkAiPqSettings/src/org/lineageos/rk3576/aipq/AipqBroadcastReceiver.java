package org.lineageos.rk3576.aipq;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.android.tv.twopanelsettings.slices.TvSettingsSliceProvider;

/**
 * Applies knob changes fired by the slice rows in TvSettings and invalidates
 * the slice so the two-panel re-renders with the new state.
 *
 * The renderer fires the row's action intent with extra_preference_key filled
 * in (SliceShard.firePendingIntent); the knob name travels in our own extra on
 * the same intent, so identification does not depend on theirs. Switch rows
 * carry no state: flip the current value, like the fork's dialog fragments do.
 */
public class AipqBroadcastReceiver extends BroadcastReceiver {

    static final String ACTION_KNOB = "org.lineageos.rk3576.aipq.action.KNOB";
    static final String EXTRA_KNOB = "knob";
    static final String EXTRA_VALUE = "value";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (!ACTION_KNOB.equals(intent.getAction())) {
            return;
        }
        String knob = intent.getStringExtra(EXTRA_KNOB);
        if (knob == null) {
            knob = knobFromKey(intent.getStringExtra(
                    AipqSliceProvider.EXTRA_PREFERENCE_KEY));
        }
        if (knob == null) {
            return;
        }
        switch (knob) {
            case AipqProps.KNOB_MASTER:
                AipqProps.applyMaster(context, !AipqProps.isMasterOn(context));
                break;
            case AipqProps.KNOB_SR:
                AipqProps.applySr(context, intent.getIntExtra(EXTRA_VALUE, 0));
                break;
            case AipqProps.KNOB_DC:
                AipqProps.applyDc(context, intent.getIntExtra(EXTRA_VALUE, 0));
                break;
            case AipqProps.KNOB_MEMC:
                AipqProps.applyMemc(context, intent.getIntExtra(EXTRA_VALUE, 0));
                break;
            case AipqProps.KNOB_FE:
                AipqProps.applyFe(context, !AipqProps.isFeOn(context));
                break;
            case AipqProps.KNOB_ACM:
                AipqProps.applyAcm(context, !AipqProps.isAcmOn(context));
                break;
            case AipqProps.KNOB_DCI:
                AipqProps.applyDci(context, !AipqProps.isDciOn(context));
                break;
            case AipqProps.KNOB_SD:
                AipqProps.applySd(context, !AipqProps.isSdOn(context));
                break;
            case AipqProps.KNOB_DEMO:
                AipqProps.applyDemo(context, intent.getIntExtra(EXTRA_VALUE, 0));
                break;
            default:
                return;
        }
        TvSettingsSliceProvider.invalidateSlice(context, AipqSliceProvider.SLICE_URI);
    }

    /** Row keys are "aipq_<knob>", "aipq_<knob>_<value>" or "aipq_<knob>_group". */
    private static String knobFromKey(String key) {
        if (key == null || !key.startsWith("aipq_")) {
            return null;
        }
        String rest = key.substring("aipq_".length());
        int cut = rest.indexOf('_');
        return cut < 0 ? rest : rest.substring(0, cut);
    }
}
