using Uno;
using Uno.IO;
using Uno.Compiler.ExportTargetInterop;
using Uno.Collections;

namespace Fuse.Shortcut
{
	[ForeignInclude(Language.Java,
		"android.annotation.TargetApi",
		"android.os.Build",
		"android.content.pm.ShortcutInfo",
		"android.content.pm.ShortcutManager",
		"android.content.Intent",
		"android.content.Context",
		"android.app.Activity",
		"android.content.res.AssetManager",
		"android.graphics.Bitmap",
		"android.graphics.BitmapFactory",
		"android.graphics.Canvas",
		"android.graphics.Paint",
		"android.graphics.Typeface",
		"android.graphics.drawable.Icon",
		"android.text.TextPaint",
		"org.json.JSONArray",
		"org.json.JSONObject")]
	[ForeignInclude(Language.ObjC, "iOS/FOShortcutHandler.h")]
	[Require("appDelegate.sourceFile.declaration", "#include <iOS/FOShortcutHandler.h>")]
	[Require("appDelegate.sourceFile.didFinishLaunchingWithOptions", "return [[FOShortcutHandler sharedInstance] application:application didFinishLaunchingWithOptions:launchOptions];")]
	[Require("appDelegate.sourceFile.implementationScope", "- (void)applicationDidBecomeActive:(UIApplication *)application { uAutoReleasePool pool; [[FOShortcutHandler sharedInstance] applicationDidBecomeActive:application]; }")]
	[Require("appDelegate.sourceFile.implementationScope", "- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL succeeded))completionHandler { uAutoReleasePool pool; [[FOShortcutHandler sharedInstance] application:application performActionForShortcutItem:shortcutItem completionHandler:completionHandler]; }")]
	public class ShortcutProvider
	{
		/**
			Creates or replaces the dynamic shortcuts.
		*/
		public static bool RegisterShortcuts(string shortcuts, Action<string> callback)
		{
			if defined(iOS)
			{
				string error = null;
				var result = RegisterIOSShortcuts(deserialize(shortcuts), callback, msg => { error = msg; });
				if (!result && !string.IsNullOrEmpty(error))
					throw new Exception(error);
				return result;
			}
			if defined(Android)
			{
				string error = null;
				var result = RegisterAndroidShortcuts(deserialize(shortcuts), callback, msg => { error = msg; }, false);
				if (!result && !string.IsNullOrEmpty(error))
					throw new Exception(error);
				return result;
			}
			return false;
		}

		/**
			Adds new shortcuts and updates existing ones, leaving other shortcuts untouched.
		*/
		public static bool UpdateShortcuts(string shortcuts, Action<string> callback)
		{
			if defined(iOS)
			{
				string error = null;
				var result = UpdateIOSShortcuts(deserialize(shortcuts), callback, msg => { error = msg; });
				if (!result && !string.IsNullOrEmpty(error))
					throw new Exception(error);
				return result;
			}
			if defined(Android)
			{
				string error = null;
				var result = RegisterAndroidShortcuts(deserialize(shortcuts), callback, msg => { error = msg; }, true);
				if (!result && !string.IsNullOrEmpty(error))
					throw new Exception(error);
				return result;
			}
			return false;
		}

		public static bool RemoveShortcuts(string ids)
		{
			if defined(iOS)
				return RemoveIOSShortcuts(deserializeIds(ids));
			if defined(Android)
			{
				string error = null;
				var result = RemoveAndroidShortcuts(ids, msg => { error = msg; });
				if (!result && !string.IsNullOrEmpty(error))
					throw new Exception(error);
				return result;
			}
			return false;
		}

		public static bool ClearShortcuts()
		{
			if defined(iOS)
				return ClearIOSShortcuts();
			if defined(Android)
			{
				string error = null;
				var result = ClearAndroidShortcuts(msg => { error = msg; });
				if (!result && !string.IsNullOrEmpty(error))
					throw new Exception(error);
				return result;
			}
			return false;
		}

		/**
			Returns the currently registered dynamic shortcuts as a JSON array.
		*/
		public static string GetShortcuts()
		{
			if defined(iOS)
				return GetIOSShortcuts();
			if defined(Android)
				return GetAndroidShortcuts();
			return "[]";
		}

		public static bool IsSupported()
		{
			if defined(iOS)
				return true;
			if defined(Android)
				return IsAndroidSupported();
			return false;
		}

		public static int GetMaxShortcutCount()
		{
			if defined(iOS)
				return 4;
			if defined(Android)
			{
				if (!IsAndroidSupported())
					return 0;
				return GetAndroidMaxShortcutCount();
			}
			return 0;
		}

		/**
			Resolves a universal symbol name (as used by `Symbols`) to the
			platform specific icon name.
		*/
		public static string GetSystemIconName(string universalName, bool isFilled)
		{
			if (string.IsNullOrEmpty(universalName))
				return null;

			return Fuse.Controls.Primitives.SymbolProvider.GetPlatformSymbol(universalName, isFilled).Name;
		}

		public static bool ReportShortcutUsed(string id)
		{
			if defined(Android)
			{
				string error = null;
				var result = ReportAndroidShortcutUsed(id, msg => { error = msg; });
				if (!result && !string.IsNullOrEmpty(error))
					throw new Exception(error);
				return result;
			}
			// No equivalent API on iOS.
			return false;
		}

		public static string GetBundlePath(string path)
		{
			BundleFile bundleFile = null;
			foreach(var bf in Uno.IO.Bundle.AllFiles)
			{
				if(bf.SourcePath == path)
				{
					bundleFile = bf;
					break;
				}
			}
			if (bundleFile != null)
				return bundleFile.BundlePath;
			else
				return "";
		}

		[Foreign(Language.ObjC)]
		extern(iOS) static ObjC.Object deserialize(string shortcuts)
		@{
			NSMutableArray * arrShortcuts = [[NSMutableArray alloc] init];
			arrShortcuts = [NSJSONSerialization JSONObjectWithData: [shortcuts dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
			for (NSMutableDictionary* item in arrShortcuts)
			{
				if (![item isKindOfClass:[NSMutableDictionary class]])
					continue;

				id iconPath = item[@"icon"];
				if ([iconPath isKindOfClass:[NSString class]] && [iconPath length] > 0)
				{
					NSString * path = @{GetBundlePath(string):call(iconPath)};
					if ([path length] > 0)
						item[@"icon"] = [@"data/" stringByAppendingString:path];
					else
						[item removeObjectForKey:@"icon"];
				}

				id systemIconValue = item[@"systemIcon"];
				if ([systemIconValue isKindOfClass:[NSString class]] && [systemIconValue length] > 0)
				{
					bool filled = [item[@"systemIconFilled"] boolValue];
					NSString* symbolName = @{GetSystemIconName(string,bool):call(systemIconValue, filled)};
					if (symbolName != nil && symbolName.length > 0)
						item[@"systemIcon"] = symbolName;
					else
						[item removeObjectForKey:@"systemIcon"];
				}
			}
			return arrShortcuts;
		@}

		[Foreign(Language.ObjC)]
		extern(iOS) static ObjC.Object deserializeIds(string ids)
		@{
			NSArray* arr = [NSJSONSerialization JSONObjectWithData:[ids dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
			return [arr isKindOfClass:[NSArray class]] ? arr : @[];
		@}

		[Foreign(Language.Java)]
		extern(Android) static Java.Object deserialize(string shortcuts)
		@{
			java.util.List<org.json.JSONObject> listShortcuts = new java.util.ArrayList<>();
			try
			{
				org.json.JSONArray jsonArray = new org.json.JSONArray(shortcuts.trim());
				for (int i = 0; i < jsonArray.length(); i++)
				{
					org.json.JSONObject jsonObject = jsonArray.optJSONObject(i);
					if (jsonObject != null)
						listShortcuts.add(jsonObject);
				}
			}
			catch (org.json.JSONException je) {
				je.printStackTrace();
			}
			return listShortcuts;
		@}

		[Foreign(Language.ObjC)]
		extern(iOS) static bool RegisterIOSShortcuts(ObjC.Object data, Action<string> callback, Action<string> error)
		@{
			__block BOOL success = NO;
			__block NSString* errorMessage = nil;
			dispatch_sync(dispatch_get_main_queue(), ^{
				success = [[FOShortcutHandler sharedInstance] registerShortcuts:(NSArray*)data error:&errorMessage];
				[[FOShortcutHandler sharedInstance] registerCallback:callback];
			});
			if (!success && errorMessage != nil)
				error(errorMessage);
			return success;
		@}

		[Foreign(Language.ObjC)]
		extern(iOS) static bool UpdateIOSShortcuts(ObjC.Object data, Action<string> callback, Action<string> error)
		@{
			__block BOOL success = NO;
			__block NSString* errorMessage = nil;
			dispatch_sync(dispatch_get_main_queue(), ^{
				success = [[FOShortcutHandler sharedInstance] updateShortcuts:(NSArray*)data error:&errorMessage];
				[[FOShortcutHandler sharedInstance] registerCallback:callback];
			});
			if (!success && errorMessage != nil)
				error(errorMessage);
			return success;
		@}

		[Foreign(Language.ObjC)]
		extern(iOS) static bool RemoveIOSShortcuts(ObjC.Object ids)
		@{
			dispatch_sync(dispatch_get_main_queue(), ^{
				[[FOShortcutHandler sharedInstance] removeShortcuts:(NSArray*)ids];
			});
			return YES;
		@}

		[Foreign(Language.ObjC)]
		extern(iOS) static bool ClearIOSShortcuts()
		@{
			dispatch_sync(dispatch_get_main_queue(), ^{
				[[FOShortcutHandler sharedInstance] clearShortcuts];
			});
			return YES;
		@}

		[Foreign(Language.ObjC)]
		extern(iOS) static string GetIOSShortcuts()
		@{
			__block NSString* result = nil;
			dispatch_sync(dispatch_get_main_queue(), ^{
				result = [[FOShortcutHandler sharedInstance] getShortcuts];
			});
			return result ?: @"[]";
		@}

		[Foreign(Language.Java)]
		extern(Android) static bool IsAndroidSupported()
		@{
			return Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1;
		@}

		[Foreign(Language.Java)]
		extern(Android) static int GetAndroidMaxShortcutCount()
		@{
			try {
				ShortcutManager manager = (ShortcutManager)com.fuse.Activity.getRootActivity().getSystemService(Context.SHORTCUT_SERVICE);
				return manager == null ? 0 : manager.getMaxShortcutCountPerActivity();
			} catch (Exception e) {
				return 0;
			}
		@}

		[Foreign(Language.Java)]
		extern(Android) static bool ReportAndroidShortcutUsed(string id, Action<string> error)
		@{
			if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1)
				return false;

			try
			{
				ShortcutManager manager = (ShortcutManager)com.fuse.Activity.getRootActivity().getSystemService(Context.SHORTCUT_SERVICE);
				if (manager == null)
					return false;

				manager.reportShortcutUsed(id);
				return true;
			}
			catch (Exception e)
			{
				error.run(e.getMessage());
				return false;
			}
		@}

		[Foreign(Language.Java)]
		extern(Android) static bool RegisterAndroidShortcuts(Java.Object data, Action<string> callback, Action<string> error, bool updateOnly)
		@{
			// Do nothing for anything lower than API 25 as the functionality isn't supported.
			if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1)
				return false;

			final Activity context = com.fuse.Activity.getRootActivity();
			final ShortcutManager manager = (ShortcutManager)context.getSystemService(Context.SHORTCUT_SERVICE);
			if (manager == null)
			{
				error.run("Android ShortcutManager is not available.");
				return false;
			}

			final java.util.List<org.json.JSONObject> shortcuts = (java.util.List<org.json.JSONObject>)data;
			final java.util.List<ShortcutInfo> shortcutInfos = new java.util.ArrayList<>();
			final java.util.Map<String, String> disabledShortcuts = new java.util.HashMap<>();
			final java.util.List<String> enabledShortcuts = new java.util.ArrayList<>();
			final int iconSize = Math.max(48, Math.round(48 * context.getResources().getDisplayMetrics().density));

			for (org.json.JSONObject shortcut : shortcuts)
			{
				try
				{
					final String id = shortcut.optString("id", null);
					final String title = shortcut.optString("title", null);
					if (id == null || id.length() == 0 || title == null || title.length() == 0)
						continue;

					final String subtitle = shortcut.isNull("subtitle") ? null : shortcut.optString("subtitle", null);
					final String iconPath = shortcut.isNull("icon") ? null : shortcut.optString("icon", null);
					final String systemIcon = shortcut.isNull("systemIcon") ? null : shortcut.optString("systemIcon", null);
					final boolean systemIconFilled = shortcut.optBoolean("systemIconFilled", false);

					final ShortcutInfo.Builder builder = new ShortcutInfo.Builder(context, id);
					builder.setShortLabel(title);
					builder.setLongLabel(subtitle == null || subtitle.length() == 0 ? title : subtitle);

					if (shortcut.has("rank") && !shortcut.isNull("rank"))
						builder.setRank(shortcut.optInt("rank"));

					if (shortcut.has("categories") && !shortcut.isNull("categories"))
					{
						org.json.JSONArray categoriesArray = shortcut.optJSONArray("categories");
						if (categoriesArray != null)
						{
							java.util.Set<String> categories = new java.util.HashSet<>();
							for (int ci = 0; ci < categoriesArray.length(); ci++)
							{
								String category = categoriesArray.optString(ci, null);
								if (category != null && category.length() > 0)
									categories.add(category);
							}
							if (!categories.isEmpty())
								builder.setCategories(categories);
						}
					}

					boolean hasDisabled = shortcut.has("disabled") && !shortcut.isNull("disabled");
					boolean disabled = hasDisabled && shortcut.optBoolean("disabled", false);
					String disabledMessage = shortcut.isNull("disabledMessage") ? null : shortcut.optString("disabledMessage", null);
					if (disabledMessage != null && disabledMessage.length() > 0)
						builder.setDisabledMessage(disabledMessage);
					if (disabled)
						disabledShortcuts.put(id, disabledMessage == null ? "" : disabledMessage);
					else if (hasDisabled)
						enabledShortcuts.add(id);

					Icon icon = null;
					if (systemIcon != null && systemIcon.length() > 0)
					{
						String symbolName = @{GetSystemIconName(string,bool):call(systemIcon, systemIconFilled)};
						if (symbolName != null && symbolName.length() > 0)
						{
							android.graphics.Bitmap bitmap = (android.graphics.Bitmap)@{CreateSymbolBitmap(string,bool,int):call(symbolName, systemIconFilled, iconSize)};
							if (bitmap != null)
								icon = Icon.createWithBitmap(bitmap);
						}
					}

					if (icon == null && iconPath != null && iconPath.length() > 0)
					{
						String path = @{GetBundlePath(string):call(iconPath)};
						if (path != null && path.length() > 0)
						{
							try
							{
								java.io.InputStream stream = context.getAssets().open(path);
								android.graphics.Bitmap bitmap = android.graphics.BitmapFactory.decodeStream(stream);
								stream.close();
								if (bitmap != null)
									icon = Icon.createWithBitmap(bitmap);
							}
							catch (Exception e)
							{
								e.printStackTrace();
							}
						}
					}
					if (icon != null)
						builder.setIcon(icon);

					org.json.JSONObject extrasObj = shortcut.isNull("extras") ? null : shortcut.optJSONObject("extras");
					String extras = extrasObj == null ? "{}" : extrasObj.toString();

					if (extrasObj != null)
					{
						android.os.PersistableBundle extrasBundle = (android.os.PersistableBundle)@{CreatePersistableBundle(string):call(extrasObj.toString())};
						if (extrasBundle != null)
							builder.setExtras(extrasBundle);
					}

					Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
					if (intent == null)
					{
						error.run("Unable to create a launch intent for the application.");
						return false;
					}
					intent.setAction(Intent.ACTION_RUN);
					intent.putExtra("com.fuse.shortcut", id);
					intent.putExtra("com.fuse.shortcut.extras", extras);
					intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
					builder.setIntent(intent);

					shortcutInfos.add(builder.build());
				}
				catch (Exception e)
				{
					error.run(e.getMessage());
					return false;
				}
			}

			final java.util.concurrent.CountDownLatch latch = new java.util.concurrent.CountDownLatch(1);
			final boolean[] success = { false };
			final String[] failure = { null };

			if (!updateOnly)
			{
				int maxShortcuts = manager.getMaxShortcutCountPerActivity();
				if (maxShortcuts > 0 && shortcutInfos.size() > maxShortcuts)
				{
					error.run("Cannot register " + shortcutInfos.size() + " shortcuts; this device supports at most " + maxShortcuts + ".");
					return false;
				}
			}
			else
			{
				try
				{
					java.util.Set<String> mergedIds = new java.util.HashSet<>();
					for (ShortcutInfo existing : manager.getDynamicShortcuts())
						mergedIds.add(existing.getId());
					for (ShortcutInfo updated : shortcutInfos)
						mergedIds.add(updated.getId());

					int maxShortcuts = manager.getMaxShortcutCountPerActivity();
					if (maxShortcuts > 0 && mergedIds.size() > maxShortcuts)
					{
						error.run("Cannot update shortcuts; the resulting set would contain " + mergedIds.size() + " shortcuts, but this device supports at most " + maxShortcuts + ".");
						return false;
					}
				}
				catch (Exception e)
				{
					error.run(e.getMessage());
					return false;
				}
			}

			context.runOnUiThread(new Runnable() {
				@Override public void run()
				{
					try
					{
						if (!@{HasAndroidIntentListener():call()})
						{
							com.fuse.Activity.IntentListener listener = new com.fuse.Activity.IntentListener() {
								@Override public void onIntent(Intent intent)
								{
									if (!intent.hasExtra("com.fuse.shortcut"))
										return;

									String id = intent.getStringExtra("com.fuse.shortcut");
									String extras = intent.getStringExtra("com.fuse.shortcut.extras");
									String launchType = @{IsAndroidColdIntent():call()} ? "cold" : "resume";

									try
									{
										org.json.JSONObject extrasObj = (extras == null || extras.length() == 0)
											? new org.json.JSONObject()
											: new org.json.JSONObject(extras);
										org.json.JSONObject payload = new org.json.JSONObject();
										payload.put("id", id == null ? "" : id);
										payload.put("extras", extrasObj);
										payload.put("launchType", launchType);
										if (callback != null)
											callback.run(payload.toString());
									}
									catch (Exception e)
									{
										e.printStackTrace();
									}
								}
							};

							@{SetAndroidIntentListener(Java.Object):call(listener)};
							@{SetAndroidColdIntent(bool):call(true)};
							com.fuse.Activity.subscribeToIntents(listener, Intent.ACTION_RUN);
							@{SetAndroidColdIntent(bool):call(false)};
						}

						if (!shortcutInfos.isEmpty())
						{
							if (updateOnly)
								manager.addDynamicShortcuts(shortcutInfos);
							else
								manager.setDynamicShortcuts(shortcutInfos);
						}
						else if (!updateOnly)
						{
							manager.setDynamicShortcuts(shortcutInfos);
						}

						if (!disabledShortcuts.isEmpty())
						{
							for (java.util.Map.Entry<String, String> entry : disabledShortcuts.entrySet())
							{
								CharSequence message = (entry.getValue() == null || entry.getValue().length() == 0) ? null : entry.getValue();
								manager.disableShortcuts(java.util.Collections.singletonList(entry.getKey()), message);
							}
						}
						if (!enabledShortcuts.isEmpty())
							manager.enableShortcuts(enabledShortcuts);

						success[0] = true;
					}
					catch (Exception e)
					{
						failure[0] = e.getMessage();
					}
					finally
					{
						latch.countDown();
					}
				}
			});

			try
			{
				latch.await(5, java.util.concurrent.TimeUnit.SECONDS);
			}
			catch (InterruptedException e)
			{
				Thread.currentThread().interrupt();
				error.run("Interrupted while updating shortcuts.");
				return false;
			}

			if (failure[0] != null)
			{
				error.run(failure[0]);
				return false;
			}

			return success[0];
		@}

		[Foreign(Language.Java)]
		extern(Android) static bool RemoveAndroidShortcuts(string ids, Action<string> error)
		@{
			if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1)
				return false;

			try
			{
				ShortcutManager manager = (ShortcutManager)com.fuse.Activity.getRootActivity().getSystemService(Context.SHORTCUT_SERVICE);
				if (manager == null)
					return false;

				java.util.List<String> shortcutIds = new java.util.ArrayList<>();
				org.json.JSONArray jsonIds = new org.json.JSONArray(ids);
				for (int i = 0; i < jsonIds.length(); i++)
					shortcutIds.add(jsonIds.getString(i));

				manager.removeDynamicShortcuts(shortcutIds);
				return true;
			}
			catch (Exception e)
			{
				error.run(e.getMessage());
				return false;
			}
		@}

		[Foreign(Language.Java)]
		extern(Android) static bool ClearAndroidShortcuts(Action<string> error)
		@{
			if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1)
				return false;

			try
			{
				ShortcutManager manager = (ShortcutManager)com.fuse.Activity.getRootActivity().getSystemService(Context.SHORTCUT_SERVICE);
				if (manager == null)
					return false;

				manager.removeAllDynamicShortcuts();
				return true;
			}
			catch (Exception e)
			{
				error.run(e.getMessage());
				return false;
			}
		@}

		[Foreign(Language.Java)]
		extern(Android) static string GetAndroidShortcuts()
		@{
			if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1)
				return "[]";

			try
			{
				ShortcutManager manager = (ShortcutManager)com.fuse.Activity.getRootActivity().getSystemService(Context.SHORTCUT_SERVICE);
				if (manager == null)
					return "[]";

				org.json.JSONArray result = new org.json.JSONArray();
				for (ShortcutInfo shortcut : manager.getDynamicShortcuts())
				{
					org.json.JSONObject item = new org.json.JSONObject();
					item.put("id", shortcut.getId());
					item.put("title", shortcut.getShortLabel() == null ? "" : shortcut.getShortLabel().toString());
					if (shortcut.getLongLabel() != null)
						item.put("subtitle", shortcut.getLongLabel().toString());

					item.put("rank", shortcut.getRank());

					java.util.Set<String> categories = shortcut.getCategories();
					if (categories != null && !categories.isEmpty())
					{
						org.json.JSONArray categoryArray = new org.json.JSONArray();
						for (String category : categories)
							categoryArray.put(category);
						item.put("categories", categoryArray);
					}

					item.put("disabled", !shortcut.isEnabled());
					if (shortcut.getDisabledMessage() != null)
						item.put("disabledMessage", shortcut.getDisabledMessage().toString());

					Intent intent = shortcut.getIntent();
					if (intent != null)
					{
						String extras = intent.getStringExtra("com.fuse.shortcut.extras");
						if (extras != null && extras.length() > 0)
						{
							try {
								item.put("extras", new org.json.JSONObject(extras));
							} catch (Exception e) {
								item.put("extras", new org.json.JSONObject());
							}
						}
					}

					result.put(item);
				}
				return result.toString();
			}
			catch (Exception e)
			{
				e.printStackTrace();
				return "[]";
			}
		@}

		static object _androidIntentListener;
		static bool _androidColdIntent;

		static bool HasAndroidIntentListener()
		{
			return _androidIntentListener != null;
		}

		extern(Android) static void SetAndroidIntentListener(Java.Object listener)
		{
			_androidIntentListener = listener;
		}

		static void SetAndroidColdIntent(bool value)
		{
			_androidColdIntent = value;
		}

		static bool IsAndroidColdIntent()
		{
			return _androidColdIntent;
		}

		static string GetMaterialSymbolsPath()
		{
			foreach (var file in Uno.IO.Bundle.AllFiles)
			{
				if (file.SourcePath.EndsWith("MaterialSymbols.ttf"))
					return file.BundlePath;
			}
			return "";
		}

		static object _materialSymbolsTypeface;

		[Foreign(Language.Java)]
		extern(Android) static Java.Object LoadMaterialSymbolsTypeface()
		@{
			try
			{
				String path = @{GetMaterialSymbolsPath():call()};
				if (path == null || path.length() == 0)
					return null;

				AssetManager assets = com.fuse.Activity.getRootActivity().getAssets();
				return Typeface.createFromAsset(assets, path);
			}
			catch (Exception e)
			{
				return null;
			}
		@}

		extern(Android) static Java.Object GetMaterialSymbolsTypeface()
		{
			if (_materialSymbolsTypeface == null)
				_materialSymbolsTypeface = LoadMaterialSymbolsTypeface();
			return (Java.Object)_materialSymbolsTypeface;
		}

		[Foreign(Language.Java)]
		extern(Android) static Java.Object CreateSymbolBitmap(string symbol, bool isFilled, int size)
		@{
			android.graphics.Typeface typeface = (android.graphics.Typeface)@{GetMaterialSymbolsTypeface():call()};
			if (typeface == null)
				return null;

			android.text.TextPaint paint = new android.text.TextPaint(android.graphics.Paint.ANTI_ALIAS_FLAG | android.graphics.Paint.SUBPIXEL_TEXT_FLAG);
			paint.setTypeface(typeface);

			int color = 0xFF000000;
			try
			{
				int nightMode = com.fuse.Activity.getRootActivity().getResources().getConfiguration().uiMode & android.content.res.Configuration.UI_MODE_NIGHT_MASK;
				if (nightMode == android.content.res.Configuration.UI_MODE_NIGHT_YES)
					color = 0xFFFFFFFF;
			}
			catch (Exception e) { }

			paint.setColor(color);
			paint.setTextSize(size);
			paint.setTextAlign(android.graphics.Paint.Align.CENTER);

			if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)
			{
				try
				{
					paint.setFontVariationSettings("'FILL' " + (isFilled ? "1" : "0") + ", 'wght' 400, 'GRAD' 0, 'opsz' " + size);
				}
				catch (Exception e)
				{
					android.util.Log.w("Fuse.Shortcut", "Font variations not supported: " + e.getMessage());
				}
			}

			android.graphics.Bitmap bitmap = android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888);
			android.graphics.Canvas canvas = new android.graphics.Canvas(bitmap);
			float y = (size / 2.0f) - ((paint.descent() + paint.ascent()) / 2.0f);
			canvas.drawText(symbol, size / 2.0f, y, paint);

			return bitmap;
		@}

		[Foreign(Language.Java)]
		extern(Android) static Java.Object CreatePersistableBundle(string jsonString)
		@{
			try
			{
				final org.json.JSONObject json = new org.json.JSONObject(jsonString);

				class Converter
				{
					android.os.PersistableBundle convert(org.json.JSONObject obj) throws org.json.JSONException
					{
						android.os.PersistableBundle bundle = new android.os.PersistableBundle();
						java.util.Iterator<String> keys = obj.keys();
						while (keys.hasNext())
						{
							String key = keys.next();
							Object value = obj.get(key);
							if (value == null || value == org.json.JSONObject.NULL)
								continue;

							if (value instanceof org.json.JSONObject)
								bundle.putPersistableBundle(key, convert((org.json.JSONObject)value));
							else if (value instanceof org.json.JSONArray)
								putArray(bundle, key, (org.json.JSONArray)value);
							else if (value instanceof Boolean)
								bundle.putBoolean(key, ((Boolean)value).booleanValue());
							else if (value instanceof Integer)
								bundle.putInt(key, ((Integer)value).intValue());
							else if (value instanceof Long)
								bundle.putLong(key, ((Long)value).longValue());
							else if (value instanceof Double)
								bundle.putDouble(key, ((Double)value).doubleValue());
							else if (value instanceof String)
								bundle.putString(key, (String)value);
							else
								bundle.putString(key, value.toString());
						}
						return bundle;
					}

					void putArray(android.os.PersistableBundle bundle, String key, org.json.JSONArray array) throws org.json.JSONException
					{
						boolean allStrings = true;
						boolean allBooleans = true;
						boolean allInts = true;
						boolean allLongs = true;
						boolean allNumbers = true;

						for (int i = 0; i < array.length(); i++)
						{
							Object value = array.get(i);
							if (!(value instanceof String)) allStrings = false;
							if (!(value instanceof Boolean)) allBooleans = false;
							if (!(value instanceof Integer)) allInts = false;
							if (!(value instanceof Long)) allLongs = false;
							if (!(value instanceof Number)) allNumbers = false;
						}

						if (allStrings)
						{
							String[] values = new String[array.length()];
							for (int i = 0; i < array.length(); i++)
								values[i] = array.getString(i);
							bundle.putStringArray(key, values);
						}
						else if (allBooleans)
						{
							boolean[] values = new boolean[array.length()];
							for (int i = 0; i < array.length(); i++)
								values[i] = array.getBoolean(i);
							bundle.putBooleanArray(key, values);
						}
						else if (allInts)
						{
							int[] values = new int[array.length()];
							for (int i = 0; i < array.length(); i++)
								values[i] = array.getInt(i);
							bundle.putIntArray(key, values);
						}
						else if (allLongs)
						{
							long[] values = new long[array.length()];
							for (int i = 0; i < array.length(); i++)
								values[i] = array.getLong(i);
							bundle.putLongArray(key, values);
						}
						else if (allNumbers)
						{
							double[] values = new double[array.length()];
							for (int i = 0; i < array.length(); i++)
								values[i] = array.getDouble(i);
							bundle.putDoubleArray(key, values);
						}
						else
						{
							// PersistableBundle has no nested-object array type; preserve as JSON.
							bundle.putString(key, array.toString());
						}
					}
				}

				return new Converter().convert(json);
			}
			catch (Exception e)
			{
				return null;
			}
		@}
	}
}
