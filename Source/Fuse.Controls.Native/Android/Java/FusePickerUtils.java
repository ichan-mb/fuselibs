package com.fuse.android.widget;

import android.content.Context;
import android.content.res.Configuration;
import android.util.TypedValue;
import android.view.ContextThemeWrapper;
import android.widget.TextView;

public final class FusePickerUtils {

    private FusePickerUtils() {}

    public static Context createContext(Context base, String localeId) {
        if (localeId == null || localeId.length() == 0)
            return base;

        java.util.Locale locale = java.util.Locale.forLanguageTag(localeId.replace('_', '-'));
        Configuration config = new Configuration(base.getResources().getConfiguration());
        config.setLocale(locale);

        ContextThemeWrapper wrapper = new ContextThemeWrapper(base, 0);
        wrapper.applyOverrideConfiguration(config);
        return wrapper;
    }

    public static java.util.Locale getLocale(Context context) {
        Configuration config = context.getResources().getConfiguration();
        if (android.os.Build.VERSION.SDK_INT >= 24)
            return config.getLocales().get(0);
        else
            return config.locale;
    }

    public static android.widget.FrameLayout createFrameLayout() {
        android.widget.FrameLayout frameLayout =
            new android.widget.FrameLayout(com.fuse.Activity.getRootActivity());
        frameLayout.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
            android.view.ViewGroup.LayoutParams.MATCH_PARENT));
        return frameLayout;
    }

    public static android.widget.TextView createCompactLabel(Context context) {
        android.widget.TextView label = new android.widget.TextView(context);
        label.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        label.setText("");
        return label;
    }

    public static String formatDate(Context context, long msSince1970InUtc, String dateFormat) {
        java.util.Calendar cal = getUtcCalendar(msSince1970InUtc);

        java.text.DateFormat formatter;
        if (dateFormat == null || dateFormat.length() == 0) {
            formatter = android.text.format.DateFormat.getMediumDateFormat(context);
        } else {
            try {
                formatter = new java.text.SimpleDateFormat(dateFormat, getLocale(context));
            } catch (IllegalArgumentException e) {
                formatter = android.text.format.DateFormat.getMediumDateFormat(context);
            }
        }

        formatter.setTimeZone(java.util.TimeZone.getTimeZone("UTC"));
        return formatter.format(cal.getTime());
    }

    public static String formatTime(Context context, long msSince1970InUtc, boolean is24HourView) {
        java.util.Calendar cal = getUtcCalendar(msSince1970InUtc);
        java.util.Locale locale = getLocale(context);

        String skeleton = is24HourView ? "Hm" : "hm";
        String pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, skeleton);

        java.text.SimpleDateFormat formatter = new java.text.SimpleDateFormat(pattern, locale);
        formatter.setTimeZone(java.util.TimeZone.getTimeZone("UTC"));
        return formatter.format(cal.getTime());
    }

    public static void dismissDialog(Object dialog) {
        if (dialog != null)
            ((android.app.Dialog)dialog).dismiss();
    }

    public static void applyLabelColor(TextView label, float r, float g, float b, float a) {
        if (label == null)
            return;

        if (a > 0) {
            label.setTextColor(toColor(r, g, b, a));
            return;
        }

        Context context = label.getContext();
        TypedValue value = new TypedValue();
        if (context.getTheme().resolveAttribute(android.R.attr.textColorPrimary, value, true)) {
            if (value.resourceId != 0)
                label.setTextColor(context.getResources().getColorStateList(value.resourceId));
            else
                label.setTextColor(value.data);
        } else {
            label.setTextColor(android.graphics.Color.DKGRAY);
        }
    }

    // DatePicker setMinDate/setMaxDate use the default time zone, not UTC.
    public static long toDefaultTimezoneTicks(long msSince1970InUtc) {
        long offset = java.util.TimeZone.getDefault().getOffset(msSince1970InUtc);
        return msSince1970InUtc - offset;
    }

    public static int toColor(float r, float g, float b, float a) {
        return android.graphics.Color.argb(toByte(a), toByte(r), toByte(g), toByte(b));
    }

    private static int toByte(float value) {
        int v = (int)(value * 255.0f);
        return Math.max(0, Math.min(255, v));
    }

    public static int withAlpha(int color, float alpha) {
        return (color & 0x00FFFFFF) | (toByte(alpha) << 24);
    }

    private static java.util.Calendar getUtcCalendar(long msSince1970InUtc) {
        java.util.Calendar cal = java.util.Calendar.getInstance(
            java.util.TimeZone.getTimeZone("UTC"), java.util.Locale.getDefault());
        cal.setTimeInMillis(msSince1970InUtc);
        return cal;
    }
}
