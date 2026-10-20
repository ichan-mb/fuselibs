using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Alerts
{
	[ForeignInclude(Language.Java, "java.lang.Runnable", "android.app.AlertDialog", "com.fuse.Activity", "android.content.DialogInterface", "android.widget.EditText", "android.widget.FrameLayout", "android.widget.ArrayAdapter", "android.widget.TextView", "android.widget.Button", "android.view.View", "android.view.ViewGroup", "android.view.WindowManager", "android.text.InputType", "android.text.TextWatcher", "android.text.Editable", "android.util.TypedValue")]
	public partial class NativeAlerts
	{

		[Foreign(Language.Java)]
		extern (android) internal static void AlertNative(String title, String message, String okButtonLabel, Action onOK, Action onCancel, Action<string> onError, Action onDismiss)
		@{
			final android.app.Activity activity = com.fuse.Activity.getRootActivity();
			if (activity == null || activity.isFinishing() || activity.isDestroyed())
			{
				onError.run("No active Android activity to show the alert.");
				onDismiss.run();
				return;
			}

			Runnable r = new Runnable() {
				@Override
				public void run() {
					final android.app.Activity currentActivity = com.fuse.Activity.getRootActivity();
					if (currentActivity == null || currentActivity.isFinishing() || currentActivity.isDestroyed())
					{
						onError.run("No active Android activity to show the alert.");
						onDismiss.run();
						return;
					}

					AlertDialog alertDialog = new AlertDialog.Builder(currentActivity)
						.setMessage(message)
						.setTitle(title)
						.setPositiveButton(okButtonLabel, new DialogInterface.OnClickListener()
						{
							@Override
							public void onClick(DialogInterface dialog, int which)
							{
								onOK.run();
							}
						})
						.setOnCancelListener(new DialogInterface.OnCancelListener()
						{
							@Override
							public void onCancel(DialogInterface dialog)
							{
								onCancel.run();
							}
						})
						.setOnDismissListener(new DialogInterface.OnDismissListener()
						{
							@Override
							public void onDismiss(DialogInterface dialog)
							{
								com.fuse.alerts.AlertDialogHandle.clearCurrent();
								onDismiss.run();
							}
						})
						.create();
					com.fuse.alerts.AlertDialogHandle.setCurrent(alertDialog);
					alertDialog.show();
				}
			};
			activity.runOnUiThread(r);
		@}

		[Foreign(Language.Java)]
		extern (android) internal static void ConfirmNative(String title, String message, String okButtonLabel, String cancelButtonLabel, Action onOK, Action onCancel, Action<string> onError, Action onDismiss)
		@{
			final android.app.Activity activity = com.fuse.Activity.getRootActivity();
			if (activity == null || activity.isFinishing() || activity.isDestroyed())
			{
				onError.run("No active Android activity to show the confirm dialog.");
				onDismiss.run();
				return;
			}

			Runnable r = new Runnable() {
				@Override
				public void run() {
					final android.app.Activity currentActivity = com.fuse.Activity.getRootActivity();
					if (currentActivity == null || currentActivity.isFinishing() || currentActivity.isDestroyed())
					{
						onError.run("No active Android activity to show the confirm dialog.");
						onDismiss.run();
						return;
					}

					AlertDialog alertDialog = new AlertDialog.Builder(currentActivity)
						.setMessage(message)
						.setTitle(title)
						.setPositiveButton(okButtonLabel, new DialogInterface.OnClickListener()
						{
							@Override
							public void onClick(DialogInterface dialog, int which)
							{
								onOK.run();
							}
						})
						.setNegativeButton(cancelButtonLabel, new DialogInterface.OnClickListener()
						{
							@Override
							public void onClick(DialogInterface dialog, int which)
							{
								onCancel.run();
							}
						})
						.setOnCancelListener(new DialogInterface.OnCancelListener()
						{
							@Override
							public void onCancel(DialogInterface dialog)
							{
								onCancel.run();
							}
						})
						.setOnDismissListener(new DialogInterface.OnDismissListener()
						{
							@Override
							public void onDismiss(DialogInterface dialog)
							{
								com.fuse.alerts.AlertDialogHandle.clearCurrent();
								onDismiss.run();
							}
						})
						.create();
					com.fuse.alerts.AlertDialogHandle.setCurrent(alertDialog);
					alertDialog.show();
				}
			};
			activity.runOnUiThread(r);
		@}


		[Foreign(Language.Java)]
		extern (android) internal static void PromptNative(String title, String message, String placeholder, String value, String okButtonLabel, String cancelButtonLabel, bool secure, String keyboardType, int minChars, Action<string> onOK, Action onCancel, Action<string> onError, Action onDismiss)
		@{
			final android.app.Activity activity = com.fuse.Activity.getRootActivity();
			if (activity == null || activity.isFinishing() || activity.isDestroyed())
			{
				onError.run("No active Android activity to show the prompt.");
				onDismiss.run();
				return;
			}

			Runnable r = new Runnable() {
				@Override
				public void run() {
					final android.app.Activity currentActivity = com.fuse.Activity.getRootActivity();
					if (currentActivity == null || currentActivity.isFinishing() || currentActivity.isDestroyed())
					{
						onError.run("No active Android activity to show the prompt.");
						onDismiss.run();
						return;
					}

					final EditText input = new EditText(currentActivity);
					input.setHint(placeholder);
					input.setText(value);
					input.setSingleLine(true);
					input.setSelectAllOnFocus(true);

					int inputType = InputType.TYPE_CLASS_TEXT;
					if (secure)
						inputType = InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD;
					else if ("email".equals(keyboardType))
						inputType = InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS;
					else if ("number".equals(keyboardType))
						inputType = InputType.TYPE_CLASS_NUMBER;
					else if ("phone".equals(keyboardType))
						inputType = InputType.TYPE_CLASS_PHONE;
					else if ("url".equals(keyboardType))
						inputType = InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI;
					input.setInputType(inputType);

					int padding = (int)(16 * currentActivity.getResources().getDisplayMetrics().density);
					FrameLayout container = new FrameLayout(currentActivity);
					container.setPadding(padding, padding / 2, padding, 0);
					container.addView(input);

					AlertDialog.Builder builder = new AlertDialog.Builder(currentActivity)
						.setTitle(title)
						.setView(container)
						.setPositiveButton(okButtonLabel, new DialogInterface.OnClickListener()
						{
							@Override
							public void onClick(DialogInterface dialog, int which)
							{
								onOK.run(input.getText().toString());
							}
						})
						.setNegativeButton(cancelButtonLabel, new DialogInterface.OnClickListener()
						{
							@Override
							public void onClick(DialogInterface dialog, int which)
							{
								onCancel.run();
							}
						})
						.setOnCancelListener(new DialogInterface.OnCancelListener()
						{
							@Override
							public void onCancel(DialogInterface dialog)
							{
								onCancel.run();
							}
						})
						.setOnDismissListener(new DialogInterface.OnDismissListener()
						{
							@Override
							public void onDismiss(DialogInterface dialog)
							{
								com.fuse.alerts.AlertDialogHandle.clearCurrent();
								onDismiss.run();
							}
						});

					if (message != null && message.length() > 0)
						builder.setMessage(message);

					final AlertDialog dialog = builder.create();
					com.fuse.alerts.AlertDialogHandle.setCurrent(dialog);

					if (minChars > 0)
					{
						input.addTextChangedListener(new TextWatcher()
						{
							@Override
							public void beforeTextChanged(CharSequence s, int start, int count, int after) { }

							@Override
							public void onTextChanged(CharSequence s, int start, int before, int count) { }

							@Override
							public void afterTextChanged(Editable s)
							{
								Button positive = dialog.getButton(AlertDialog.BUTTON_POSITIVE);
								if (positive != null)
									positive.setEnabled(s.length() >= minChars);
							}
						});
					}

					dialog.setOnShowListener(new DialogInterface.OnShowListener()
					{
						@Override
						public void onShow(DialogInterface d)
						{
							input.requestFocus();
							dialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE);

							if (minChars > 0)
							{
								Button positive = dialog.getButton(AlertDialog.BUTTON_POSITIVE);
								if (positive != null)
									positive.setEnabled(input.getText().length() >= minChars);
							}
						}
					});
					dialog.show();
				}
			};
			activity.runOnUiThread(r);
		@}

		[Foreign(Language.Java)]
		extern (android) internal static void ActionSheetNative(String title, String message, String[] items, bool[] destructive, bool[] enabled, String cancelButtonLabel, Action<int> onSelect, Action onCancel, Action<string> onError, Action onDismiss)
		@{
			final android.app.Activity activity = com.fuse.Activity.getRootActivity();
			if (activity == null || activity.isFinishing() || activity.isDestroyed())
			{
				onError.run("No active Android activity to show the action sheet.");
				onDismiss.run();
				return;
			}

			Runnable r = new Runnable() {
				@Override
				public void run() {
					final android.app.Activity currentActivity = com.fuse.Activity.getRootActivity();
					if (currentActivity == null || currentActivity.isFinishing() || currentActivity.isDestroyed())
					{
						onError.run("No active Android activity to show the action sheet.");
						onDismiss.run();
						return;
					}

					final String[] labels = items.copyArray();
					final boolean[] destructiveFlags = destructive.copyArray();
					final boolean[] enabledFlags = enabled.copyArray();

					TypedValue typedValue = new TypedValue();
					int resolvedTextColor = 0xFF000000;
					if (currentActivity.getTheme().resolveAttribute(android.R.attr.textColorPrimary, typedValue, true) && typedValue.resourceId != 0)
						resolvedTextColor = currentActivity.getResources().getColorStateList(typedValue.resourceId).getDefaultColor();
					final int defaultTextColor = resolvedTextColor;

					ArrayAdapter<String> adapter = new ArrayAdapter<String>(currentActivity, android.R.layout.simple_list_item_1, labels) {
						@Override
						public View getView(int position, View convertView, ViewGroup parent)
						{
							TextView view = (TextView)super.getView(position, convertView, parent);
							boolean isDestructive = position < destructiveFlags.length && destructiveFlags[position];
							boolean isEnabled = position >= enabledFlags.length || enabledFlags[position];
							view.setTextColor(isDestructive ? 0xFFD32F2F : defaultTextColor);
							view.setEnabled(isEnabled);
							view.setAlpha(isEnabled ? 1.0f : 0.5f);
							return view;
						}
					};

					String dialogTitle = title;
					if (message != null && message.length() > 0)
						dialogTitle = (title != null && title.length() > 0) ? title + "\n" + message : message;

					AlertDialog.Builder builder = new AlertDialog.Builder(currentActivity)
						.setTitle(dialogTitle)
						.setAdapter(adapter, new DialogInterface.OnClickListener()
						{
							@Override
							public void onClick(DialogInterface dialog, int which)
							{
								if (which >= 0 && which < enabledFlags.length && !enabledFlags[which])
									return;
								onSelect.run(which);
							}
						})
						.setNegativeButton(cancelButtonLabel, new DialogInterface.OnClickListener()
						{
							@Override
							public void onClick(DialogInterface dialog, int which)
							{
								onCancel.run();
							}
						})
						.setOnCancelListener(new DialogInterface.OnCancelListener()
						{
							@Override
							public void onCancel(DialogInterface dialog)
							{
								onCancel.run();
							}
						})
						.setOnDismissListener(new DialogInterface.OnDismissListener()
						{
							@Override
							public void onDismiss(DialogInterface dialog)
							{
								com.fuse.alerts.AlertDialogHandle.clearCurrent();
								onDismiss.run();
							}
						});

					AlertDialog alertDialog = builder.create();
					com.fuse.alerts.AlertDialogHandle.setCurrent(alertDialog);
					alertDialog.show();
				}
			};
			activity.runOnUiThread(r);
		@}

		[Foreign(Language.Java)]
		extern (android) internal static void ConfirmChoiceNative(String title, String message, String okButtonLabel, String neutralButtonLabel, String cancelButtonLabel, bool destructive, bool cancelable, Action onOK, Action onNeutral, Action onCancel, Action<string> onError, Action onDismiss)
		@{
			final android.app.Activity activity = com.fuse.Activity.getRootActivity();
			if (activity == null || activity.isFinishing() || activity.isDestroyed())
			{
				onError.run("No active Android activity to show the confirm dialog.");
				onDismiss.run();
				return;
			}

			Runnable r = new Runnable() {
				@Override
				public void run() {
					final android.app.Activity currentActivity = com.fuse.Activity.getRootActivity();
					if (currentActivity == null || currentActivity.isFinishing() || currentActivity.isDestroyed())
					{
						onError.run("No active Android activity to show the confirm dialog.");
						onDismiss.run();
						return;
					}

					AlertDialog.Builder builder = new AlertDialog.Builder(currentActivity)
						.setMessage(message)
						.setTitle(title)
						.setCancelable(cancelable)
						.setPositiveButton(okButtonLabel, new DialogInterface.OnClickListener()
						{
							@Override
							public void onClick(DialogInterface dialog, int which)
							{
								onOK.run();
							}
						})
						.setNegativeButton(cancelButtonLabel, new DialogInterface.OnClickListener()
						{
							@Override
							public void onClick(DialogInterface dialog, int which)
							{
								onCancel.run();
							}
						})
						.setOnDismissListener(new DialogInterface.OnDismissListener()
						{
							@Override
							public void onDismiss(DialogInterface dialog)
							{
								com.fuse.alerts.AlertDialogHandle.clearCurrent();
								onDismiss.run();
							}
						});

					if (neutralButtonLabel != null && neutralButtonLabel.length() > 0)
					{
						builder.setNeutralButton(neutralButtonLabel, new DialogInterface.OnClickListener()
						{
							@Override
							public void onClick(DialogInterface dialog, int which)
							{
								onNeutral.run();
							}
						});
					}

					AlertDialog alertDialog = builder.create();
					com.fuse.alerts.AlertDialogHandle.setCurrent(alertDialog);
					alertDialog.show();

					if (destructive)
						alertDialog.getButton(AlertDialog.BUTTON_POSITIVE).setTextColor(0xFFD32F2F);
				}
			};
			activity.runOnUiThread(r);
		@}

		[Foreign(Language.Java)]
		extern (android) internal static void DismissAllNative()
		@{
			final android.app.Activity activity = com.fuse.Activity.getRootActivity();
			if (activity != null && !activity.isFinishing() && !activity.isDestroyed())
			{
				activity.runOnUiThread(new Runnable() {
					@Override
					public void run() {
						com.fuse.alerts.AlertDialogHandle.dismissCurrent();
					}
				});
			}
			else
			{
				com.fuse.alerts.AlertDialogHandle.dismissCurrent();
			}
		@}

		[Foreign(Language.Java)]
		extern (android) static string DefaultOkLabel()
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			return activity != null ? activity.getString(android.R.string.ok) : "OK";
		@}

		[Foreign(Language.Java)]
		extern (android) static string DefaultCancelLabel()
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			return activity != null ? activity.getString(android.R.string.cancel) : "Cancel";
		@}


	}
}
