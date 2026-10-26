package com.fuse.android.widget;

import android.app.DatePickerDialog;
import android.content.Context;
import android.widget.CalendarView;
import android.widget.DatePicker;
import android.widget.TextView;

public final class FuseDatePicker {

    private FuseDatePicker() {}

    public static DatePicker createDatePicker(Context context, String localeId) {
        java.util.Locale previous = java.util.Locale.getDefault();
        applyDefaultLocale(localeId);
        try {
            return new DatePicker(context);
        } finally {
            java.util.Locale.setDefault(previous);
        }
    }

    public static DatePickerDialog createDatePickerDialog(Context context,
            DatePickerDialog.OnDateSetListener listener, int year, int month, int dayOfMonth,
            String localeId) {
        java.util.Locale previous = java.util.Locale.getDefault();
        applyDefaultLocale(localeId);
        try {
            return new DatePickerDialog(context, listener, year, month, dayOfMonth);
        } finally {
            java.util.Locale.setDefault(previous);
        }
    }

    // The DatePicker spinner delegate reads Locale.getDefault() at construction time.
    static void applyDefaultLocale(String localeId) {
        if (localeId == null || localeId.length() == 0)
            return;
        java.util.Locale.setDefault(
            java.util.Locale.forLanguageTag(localeId.replace('_', '-')));
    }

    public static void applyFirstDayOfWeek(DatePicker datePicker, int firstDayOfWeek) {
        if (datePicker == null || firstDayOfWeek < 1 || firstDayOfWeek > 7)
            return;

        datePicker.setFirstDayOfWeek(firstDayOfWeek);
    }

    public static void applyTint(DatePicker datePicker, TextView label, float r, float g, float b, float a) {
        FusePickerUtils.applyLabelColor(label, r, g, b, a);

        if (datePicker == null || a <= 0)
            return;

        CalendarView calendarView = datePicker.getCalendarView();
        if (calendarView == null)
            return;

        int color = FusePickerUtils.toColor(r, g, b, a);
        calendarView.setSelectedWeekBackgroundColor(FusePickerUtils.withAlpha(color, 0.2f));
        calendarView.setFocusedMonthDateColor(color);
        calendarView.setUnfocusedMonthDateColor(FusePickerUtils.withAlpha(color, 0.4f));
        calendarView.setWeekSeparatorLineColor(FusePickerUtils.withAlpha(color, 0.2f));
    }
}
