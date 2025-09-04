using Uno.Collections;

namespace Fuse.Controls.Primitives
{
	public class SymbolInfo
	{
		public string IOSName { get; private set; }
		public string AndroidName { get; private set; }
		public bool HasFillVariant { get; private set; }

		public SymbolInfo(string iOSName, string androidName, bool hasFillVariant = true)
		{
			IOSName = iOSName;
			AndroidName = androidName;
			HasFillVariant = hasFillVariant;
		}
	}

	public static class SymbolMapping
	{
		public static readonly Dictionary<string, SymbolInfo> All = CreateSymbolMappings();

		static Dictionary<string, SymbolInfo> CreateSymbolMappings()
		{
			var mappings = new Dictionary<string, SymbolInfo>();

			// Missing/Fallback Symbol
			mappings.Add("missing_symbol", new SymbolInfo("questionmark.circle", "help", false));

			// Common Actions
			mappings.Add("square.and.pencil", new SymbolInfo("square.and.pencil", "edit_square"));
			mappings.Add("trash", new SymbolInfo("trash", "delete"));
			mappings.Add("gear", new SymbolInfo("gear", "settings"));
			mappings.Add("plus", new SymbolInfo("plus", "add", false));
			mappings.Add("camera", new SymbolInfo("camera", "photo_camera"));
			mappings.Add("heart", new SymbolInfo("heart", "favorite"));
			mappings.Add("star", new SymbolInfo("star", "star"));
			mappings.Add("person", new SymbolInfo("person", "person"));
			mappings.Add("house", new SymbolInfo("house", "home"));
			mappings.Add("magnifyingglass", new SymbolInfo("magnifyingglass", "search", false));
			mappings.Add("minus", new SymbolInfo("minus", "remove", false));
			mappings.Add("xmark", new SymbolInfo("xmark", "close", false));
			mappings.Add("checkmark", new SymbolInfo("checkmark", "check", false));
			mappings.Add("square.and.arrow.up", new SymbolInfo("square.and.arrow.up", "share", false));
			mappings.Add("square.and.arrow.down", new SymbolInfo("square.and.arrow.down", "save_alt", false));
			mappings.Add("pencil", new SymbolInfo("pencil", "edit"));
			mappings.Add("bookmark", new SymbolInfo("bookmark", "bookmark"));
			mappings.Add("folder", new SymbolInfo("folder", "folder"));
			mappings.Add("paperplane", new SymbolInfo("paperplane", "send"));
			mappings.Add("tray", new SymbolInfo("tray", "inbox"));
			mappings.Add("archivebox", new SymbolInfo("archivebox", "archive"));
			mappings.Add("doc", new SymbolInfo("doc", "article"));
			mappings.Add("doc.on.doc", new SymbolInfo("doc.on.doc", "content_copy", false));
			mappings.Add("link", new SymbolInfo("link", "link", false));
			mappings.Add("ellipsis", new SymbolInfo("ellipsis", "more_horiz", false));
			mappings.Add("ellipsis.circle", new SymbolInfo("ellipsis.circle", "more_vert"));
			mappings.Add("rectangle.and.pencil.and.ellipsis", new SymbolInfo("rectangle.and.pencil.and.ellipsis", "edit_note"));
			mappings.Add("square.and.arrow.up.trianglebadge.exclamationmark", new SymbolInfo("square.and.arrow.up.trianglebadge.exclamationmark", "warning", false));
			mappings.Add("paintbrush", new SymbolInfo("paintbrush", "brush"));
			mappings.Add("wrench", new SymbolInfo("wrench", "build"));
			mappings.Add("hammer", new SymbolInfo("hammer", "construction"));
			mappings.Add("scissors", new SymbolInfo("scissors", "content_cut"));
			mappings.Add("slider.horizontal.3", new SymbolInfo("slider.horizontal.3", "tune", false));
			mappings.Add("dial.max", new SymbolInfo("dial.max", "speed"));
			mappings.Add("speedometer", new SymbolInfo("speedometer", "dashboard"));
			mappings.Add("crown", new SymbolInfo("crown", "workspace_premium"));
			mappings.Add("gift", new SymbolInfo("gift", "card_giftcard"));
			mappings.Add("bag", new SymbolInfo("bag", "shopping_bag"));
			mappings.Add("cart", new SymbolInfo("cart", "shopping_cart"));
			mappings.Add("creditcard", new SymbolInfo("creditcard", "credit_card"));
			mappings.Add("banknote", new SymbolInfo("banknote", "payments"));
			mappings.Add("dollarsign.circle", new SymbolInfo("dollarsign.circle", "monetization_on"));
			mappings.Add("percent", new SymbolInfo("percent", "percent", false));
			mappings.Add("number", new SymbolInfo("number", "tag", false));
			mappings.Add("at", new SymbolInfo("at", "alternate_email", false));
			mappings.Add("questionmark", new SymbolInfo("questionmark", "help_outline", false));
			mappings.Add("exclamationmark", new SymbolInfo("exclamationmark", "priority_high", false));
			mappings.Add("bell", new SymbolInfo("bell", "notifications"));
			mappings.Add("bell.slash", new SymbolInfo("bell.slash", "notifications_off"));
			mappings.Add("flame", new SymbolInfo("flame", "local_fire_department"));
			mappings.Add("snow", new SymbolInfo("snow", "ac_unit", false));
			mappings.Add("drop", new SymbolInfo("drop", "water_drop"));
			mappings.Add("leaf", new SymbolInfo("leaf", "eco"));
			mappings.Add("tree", new SymbolInfo("tree", "park"));

			// Navigation
			mappings.Add("arrow.left", new SymbolInfo("arrow.left", "arrow_back", false));
			mappings.Add("arrow.right", new SymbolInfo("arrow.right", "arrow_forward", false));
			mappings.Add("arrow.up", new SymbolInfo("arrow.up", "arrow_upward", false));
			mappings.Add("arrow.down", new SymbolInfo("arrow.down", "arrow_downward", false));
			mappings.Add("chevron.left", new SymbolInfo("chevron.left", "chevron_left", false));
			mappings.Add("chevron.right", new SymbolInfo("chevron.right", "chevron_right", false));
			mappings.Add("chevron.up", new SymbolInfo("chevron.up", "expand_less", false));
			mappings.Add("chevron.down", new SymbolInfo("chevron.down", "expand_more", false));
			mappings.Add("arrow.uturn.left", new SymbolInfo("arrow.uturn.left", "undo", false));
			mappings.Add("arrow.uturn.right", new SymbolInfo("arrow.uturn.right", "redo", false));
			mappings.Add("arrow.clockwise", new SymbolInfo("arrow.clockwise", "refresh", false));
			mappings.Add("arrow.counterclockwise", new SymbolInfo("arrow.counterclockwise", "history", false));
			mappings.Add("line.horizontal.3", new SymbolInfo("line.horizontal.3", "menu", false));
			mappings.Add("location", new SymbolInfo("location", "location_on"));
			mappings.Add("map", new SymbolInfo("map", "map"));
			mappings.Add("location.north", new SymbolInfo("location.north", "navigation", false));
			mappings.Add("location.circle", new SymbolInfo("location.circle", "my_location"));
			mappings.Add("globe", new SymbolInfo("globe", "public"));
			mappings.Add("network", new SymbolInfo("network", "hub"));
			mappings.Add("arrow.up.right", new SymbolInfo("arrow.up.right", "north_east", false));
			mappings.Add("arrow.down.left", new SymbolInfo("arrow.down.left", "south_west", false));
			mappings.Add("arrow.up.left", new SymbolInfo("arrow.up.left", "north_west", false));
			mappings.Add("arrow.down.right", new SymbolInfo("arrow.down.right", "south_east", false));
			mappings.Add("arrow.up.and.down", new SymbolInfo("arrow.up.and.down", "swap_vert", false));
			mappings.Add("arrow.left.and.right", new SymbolInfo("arrow.left.and.right", "swap_horiz", false));
			mappings.Add("arrow.triangle.2.circlepath", new SymbolInfo("arrow.triangle.2.circlepath", "sync", false));
			mappings.Add("arrow.2.circlepath", new SymbolInfo("arrow.2.circlepath", "cached", false));

			// Media Control
			mappings.Add("play", new SymbolInfo("play", "play_arrow"));
			mappings.Add("pause", new SymbolInfo("pause", "pause"));
			mappings.Add("stop", new SymbolInfo("stop", "stop"));
			mappings.Add("forward", new SymbolInfo("forward", "fast_forward"));
			mappings.Add("backward", new SymbolInfo("backward", "fast_rewind"));
			mappings.Add("goforward.10", new SymbolInfo("goforward.10", "forward_10", false));
			mappings.Add("gobackward.10", new SymbolInfo("gobackward.10", "replay_10", false));
			mappings.Add("goforward.15", new SymbolInfo("goforward.15", "forward_30", false));
			mappings.Add("gobackward.15", new SymbolInfo("gobackward.15", "replay_30", false));
			mappings.Add("goforward.30", new SymbolInfo("goforward.30", "forward_30", false));
			mappings.Add("gobackward.30", new SymbolInfo("gobackward.30", "replay_30", false));
			mappings.Add("speaker.wave.2", new SymbolInfo("speaker.wave.2", "volume_up"));
			mappings.Add("speaker.slash", new SymbolInfo("speaker.slash", "volume_off"));
			mappings.Add("speaker.wave.1", new SymbolInfo("speaker.wave.1", "volume_down"));
			mappings.Add("speaker", new SymbolInfo("speaker", "volume_mute"));
			mappings.Add("mic", new SymbolInfo("mic", "mic"));
			mappings.Add("mic.slash", new SymbolInfo("mic.slash", "mic_off"));
			mappings.Add("video", new SymbolInfo("video", "videocam"));
			mappings.Add("video.slash", new SymbolInfo("video.slash", "videocam_off"));
			mappings.Add("photo", new SymbolInfo("photo", "photo"));
			mappings.Add("photo.on.rectangle", new SymbolInfo("photo.on.rectangle", "photo_library"));
			mappings.Add("photo.stack", new SymbolInfo("photo.stack", "collections"));
			mappings.Add("camera.viewfinder", new SymbolInfo("camera.viewfinder", "camera_alt"));
			mappings.Add("record.circle", new SymbolInfo("record.circle", "fiber_manual_record"));
			mappings.Add("playpause", new SymbolInfo("playpause", "play_pause", false));
			mappings.Add("shuffle", new SymbolInfo("shuffle", "shuffle", false));
			mappings.Add("repeat", new SymbolInfo("repeat", "repeat", false));
			mappings.Add("repeat.1", new SymbolInfo("repeat.1", "repeat_one", false));
			mappings.Add("airplayaudio", new SymbolInfo("airplayaudio", "cast_for_education"));
			mappings.Add("airplayvideo", new SymbolInfo("airplayvideo", "cast"));
			mappings.Add("tv", new SymbolInfo("tv", "tv"));
			mappings.Add("headphones", new SymbolInfo("headphones", "headphones"));
			mappings.Add("hifispeaker", new SymbolInfo("hifispeaker", "speaker"));
			mappings.Add("radio", new SymbolInfo("radio", "radio"));
			mappings.Add("antenna.radiowaves.left.and.right", new SymbolInfo("antenna.radiowaves.left.and.right", "wifi", false));

			// Communication
			mappings.Add("envelope", new SymbolInfo("envelope", "email"));
			mappings.Add("phone", new SymbolInfo("phone", "call"));
			mappings.Add("message", new SymbolInfo("message", "chat_bubble"));
			mappings.Add("bubble.left.and.bubble.right", new SymbolInfo("bubble.left.and.bubble.right", "chat"));
			mappings.Add("person.2", new SymbolInfo("person.2", "group"));
			mappings.Add("person.circle", new SymbolInfo("person.circle", "account_circle"));
			mappings.Add("phone.down", new SymbolInfo("phone.down", "call_end"));
			mappings.Add("phone.arrow.up.right", new SymbolInfo("phone.arrow.up.right", "call_made"));
			mappings.Add("phone.arrow.down.left", new SymbolInfo("phone.arrow.down.left", "call_received"));
			mappings.Add("phone.badge.plus", new SymbolInfo("phone.badge.plus", "add_call"));
			mappings.Add("video.fill.badge.plus", new SymbolInfo("video.fill.badge.plus", "video_call"));
			mappings.Add("envelope.open", new SymbolInfo("envelope.open", "mark_email_read"));
			mappings.Add("envelope.badge", new SymbolInfo("envelope.badge", "mark_email_unread"));
			mappings.Add("envelope.arrow.triangle.branch", new SymbolInfo("envelope.arrow.triangle.branch", "forward_to_inbox"));
			mappings.Add("phone.connection", new SymbolInfo("phone.connection", "perm_phone_msg"));
			mappings.Add("message.badge", new SymbolInfo("message.badge", "mark_chat_unread"));
			mappings.Add("bubble.left", new SymbolInfo("bubble.left", "chat_bubble_outline"));
			mappings.Add("bubble.right", new SymbolInfo("bubble.right", "chat_bubble_outline"));
			mappings.Add("quote.bubble", new SymbolInfo("quote.bubble", "format_quote"));
			mappings.Add("text.bubble", new SymbolInfo("text.bubble", "sms"));
			mappings.Add("person.3", new SymbolInfo("person.3", "groups"));
			mappings.Add("person.crop.circle", new SymbolInfo("person.crop.circle", "account_circle"));
			mappings.Add("person.crop.circle.badge.plus", new SymbolInfo("person.crop.circle.badge.plus", "person_add"));
			mappings.Add("person.crop.circle.badge.minus", new SymbolInfo("person.crop.circle.badge.minus", "person_remove"));
			mappings.Add("person.crop.circle.badge.checkmark", new SymbolInfo("person.crop.circle.badge.checkmark", "how_to_reg"));
			mappings.Add("person.crop.circle.badge.xmark", new SymbolInfo("person.crop.circle.badge.xmark", "person_off"));
			mappings.Add("person.and.person", new SymbolInfo("person.and.person", "people"));
			mappings.Add("person.wave.2", new SymbolInfo("person.wave.2", "waving_hand"));

			// Status & Alerts
			mappings.Add("info.circle", new SymbolInfo("info.circle", "info"));
			mappings.Add("questionmark.circle", new SymbolInfo("questionmark.circle", "help", false));
			mappings.Add("exclamationmark.triangle", new SymbolInfo("exclamationmark.triangle", "warning"));
			mappings.Add("exclamationmark.circle", new SymbolInfo("exclamationmark.circle", "error"));
			mappings.Add("checkmark.circle", new SymbolInfo("checkmark.circle", "check_circle"));
			mappings.Add("xmark.circle", new SymbolInfo("xmark.circle", "cancel"));
			mappings.Add("minus.circle", new SymbolInfo("minus.circle", "remove_circle"));
			mappings.Add("plus.circle", new SymbolInfo("plus.circle", "add_circle"));
			mappings.Add("hourglass", new SymbolInfo("hourglass", "hourglass_empty", false));
			mappings.Add("hourglass.bottomhalf.filled", new SymbolInfo("hourglass.bottomhalf.filled", "hourglass_bottom"));
			mappings.Add("hourglass.tophalf.filled", new SymbolInfo("hourglass.tophalf.filled", "hourglass_top"));
			mappings.Add("timer", new SymbolInfo("timer", "timer"));
			mappings.Add("stopwatch", new SymbolInfo("stopwatch", "timer"));
			mappings.Add("alarm", new SymbolInfo("alarm", "alarm"));
			mappings.Add("clock.badge.checkmark", new SymbolInfo("clock.badge.checkmark", "schedule"));
			mappings.Add("clock.arrow.circlepath", new SymbolInfo("clock.arrow.circlepath", "history"));
			mappings.Add("deskclock", new SymbolInfo("deskclock", "schedule"));
			mappings.Add("bed.double", new SymbolInfo("bed.double", "bed"));
			mappings.Add("powersleep", new SymbolInfo("powersleep", "bedtime"));
			mappings.Add("moon.stars", new SymbolInfo("moon.stars", "bedtime"));
			mappings.Add("sun.dust", new SymbolInfo("sun.dust", "wb_sunny"));
			mappings.Add("cloud.rain", new SymbolInfo("cloud.rain", "rainy"));
			mappings.Add("cloud.snow", new SymbolInfo("cloud.snow", "snowy"));
			mappings.Add("cloud.bolt", new SymbolInfo("cloud.bolt", "thunderstorm"));
			mappings.Add("thermometer.sun", new SymbolInfo("thermometer.sun", "device_thermostat"));
			mappings.Add("humidity", new SymbolInfo("humidity", "humidity_percentage"));

			// Security & Privacy
			mappings.Add("lock", new SymbolInfo("lock", "lock"));
			mappings.Add("lock.open", new SymbolInfo("lock.open", "lock_open"));
			mappings.Add("key", new SymbolInfo("key", "vpn_key"));
			mappings.Add("eye", new SymbolInfo("eye", "visibility"));
			mappings.Add("eye.slash", new SymbolInfo("eye.slash", "visibility_off"));
			mappings.Add("hand.raised", new SymbolInfo("hand.raised", "block"));
			mappings.Add("hand.raised.slash", new SymbolInfo("hand.raised.slash", "front_hand"));
			mappings.Add("shield", new SymbolInfo("shield", "shield"));
			mappings.Add("shield.lefthalf.filled", new SymbolInfo("shield.lefthalf.filled", "verified_user"));
			mappings.Add("checkmark.shield", new SymbolInfo("checkmark.shield", "verified"));
			mappings.Add("xmark.shield", new SymbolInfo("xmark.shield", "gpp_bad"));
			mappings.Add("lock.shield", new SymbolInfo("lock.shield", "enhanced_encryption"));
			mappings.Add("person.badge.key", new SymbolInfo("person.badge.key", "admin_panel_settings"));
			mappings.Add("touchid", new SymbolInfo("touchid", "fingerprint"));
			mappings.Add("faceid", new SymbolInfo("faceid", "face"));
			mappings.Add("person.text.rectangle", new SymbolInfo("person.text.rectangle", "badge"));

			// Time & Calendar
			mappings.Add("calendar", new SymbolInfo("calendar", "calendar_today"));
			mappings.Add("calendar.badge.plus", new SymbolInfo("calendar.badge.plus", "event_available"));
			mappings.Add("calendar.badge.minus", new SymbolInfo("calendar.badge.minus", "event_busy"));
			mappings.Add("calendar.circle", new SymbolInfo("calendar.circle", "today"));
			mappings.Add("clock", new SymbolInfo("clock", "schedule"));
			mappings.Add("clock.arrow.2.circlepath", new SymbolInfo("clock.arrow.2.circlepath", "update"));
			mappings.Add("clock.badge.exclamationmark", new SymbolInfo("clock.badge.exclamationmark", "schedule"));

			// Weather & Environment
			mappings.Add("cloud", new SymbolInfo("cloud", "cloud"));
			mappings.Add("cloud.sun", new SymbolInfo("cloud.sun", "wb_cloudy"));
			mappings.Add("sun.max", new SymbolInfo("sun.max", "wb_sunny", false));
			mappings.Add("moon", new SymbolInfo("moon", "brightness_2"));
			mappings.Add("moon.fill", new SymbolInfo("moon.fill", "brightness_2"));
			mappings.Add("sparkles", new SymbolInfo("sparkles", "auto_awesome"));
			mappings.Add("wind", new SymbolInfo("wind", "air"));
			mappings.Add("tornado", new SymbolInfo("tornado", "cyclone"));
			mappings.Add("hurricane", new SymbolInfo("hurricane", "cyclone"));
			mappings.Add("snowflake", new SymbolInfo("snowflake", "ac_unit"));

			// Connectivity & Network
			mappings.Add("wifi", new SymbolInfo("wifi", "wifi", false));
			mappings.Add("wifi.slash", new SymbolInfo("wifi.slash", "wifi_off", false));
			mappings.Add("personalhotspot", new SymbolInfo("personalhotspot", "wifi_hotspot"));
			mappings.Add("bluetooth", new SymbolInfo("bluetooth", "bluetooth"));
			mappings.Add("bonjour", new SymbolInfo("bonjour", "network_check"));
			mappings.Add("cable.connector", new SymbolInfo("cable.connector", "cable"));
			mappings.Add("externaldrive", new SymbolInfo("externaldrive", "storage"));
			mappings.Add("internaldrive", new SymbolInfo("internaldrive", "storage"));
			mappings.Add("opticaldiscdrive", new SymbolInfo("opticaldiscdrive", "album"));
			mappings.Add("globe.americas", new SymbolInfo("globe.americas", "language"));
			mappings.Add("globe.europe.africa", new SymbolInfo("globe.europe.africa", "language"));
			mappings.Add("globe.asia.australia", new SymbolInfo("globe.asia.australia", "language"));

			// Power & Battery
			mappings.Add("battery.100", new SymbolInfo("battery.100", "battery_full", false));
			mappings.Add("battery.75", new SymbolInfo("battery.75", "battery_6_bar", false));
			mappings.Add("battery.50", new SymbolInfo("battery.50", "battery_4_bar", false));
			mappings.Add("battery.25", new SymbolInfo("battery.25", "battery_2_bar", false));
			mappings.Add("battery.0", new SymbolInfo("battery.0", "battery_0_bar", false));
			mappings.Add("bolt", new SymbolInfo("bolt", "flash_on"));
			mappings.Add("bolt.slash", new SymbolInfo("bolt.slash", "flash_off"));
			mappings.Add("bolt.circle", new SymbolInfo("bolt.circle", "flash_on"));
			mappings.Add("bolt.slash.circle", new SymbolInfo("bolt.slash.circle", "flash_off"));
			mappings.Add("power", new SymbolInfo("power", "power_settings_new", false));
			mappings.Add("poweroff", new SymbolInfo("poweroff", "power_off", false));
			mappings.Add("poweron", new SymbolInfo("poweron", "power", false));
			mappings.Add("battery.100.bolt", new SymbolInfo("battery.100.bolt", "battery_charging_full", false));
			mappings.Add("plug", new SymbolInfo("plug", "power", false));

			// Devices & Hardware
			mappings.Add("desktopcomputer", new SymbolInfo("desktopcomputer", "desktop_windows"));
			mappings.Add("laptopcomputer", new SymbolInfo("laptopcomputer", "laptop"));
			mappings.Add("iphone", new SymbolInfo("iphone", "smartphone"));
			mappings.Add("ipad", new SymbolInfo("ipad", "tablet"));
			mappings.Add("applewatch", new SymbolInfo("applewatch", "watch"));
			mappings.Add("airpods", new SymbolInfo("airpods", "headphones"));
			mappings.Add("homepod", new SymbolInfo("homepod", "speaker"));
			mappings.Add("appletv", new SymbolInfo("appletv", "tv"));
			mappings.Add("macbook", new SymbolInfo("macbook", "laptop_mac"));
			mappings.Add("imac", new SymbolInfo("imac", "desktop_mac"));
			mappings.Add("macmini", new SymbolInfo("macmini", "computer"));
			mappings.Add("macpro", new SymbolInfo("macpro", "workstation"));
			mappings.Add("display", new SymbolInfo("display", "monitor"));
			mappings.Add("tv.and.hifispeaker.fill", new SymbolInfo("tv.and.hifispeaker.fill", "connected_tv"));
			mappings.Add("printer", new SymbolInfo("printer", "print"));
			mappings.Add("scanner", new SymbolInfo("scanner", "scanner"));
			mappings.Add("faxmachine", new SymbolInfo("faxmachine", "fax"));
			mappings.Add("keyboard", new SymbolInfo("keyboard", "keyboard"));
			mappings.Add("mouse", new SymbolInfo("mouse", "mouse"));
			mappings.Add("trackpad", new SymbolInfo("trackpad", "touch_app"));
			mappings.Add("gamecontroller", new SymbolInfo("gamecontroller", "gamepad"));
			mappings.Add("earbuds", new SymbolInfo("earbuds", "earbuds"));
			mappings.Add("homepodmini", new SymbolInfo("homepodmini", "speaker_group"));
			mappings.Add("video.circle", new SymbolInfo("video.circle", "videocam"));
			mappings.Add("memorychip", new SymbolInfo("memorychip", "memory"));
			mappings.Add("cpu", new SymbolInfo("cpu", "developer_board"));
			mappings.Add("sdcard", new SymbolInfo("sdcard", "sd_card"));
			mappings.Add("usb", new SymbolInfo("usb", "usb"));
			mappings.Add("cable.connector.horizontal", new SymbolInfo("cable.connector.horizontal", "cable"));
			mappings.Add("projector", new SymbolInfo("projector", "video_projector"));
			mappings.Add("lightbulb", new SymbolInfo("lightbulb", "lightbulb"));
			mappings.Add("lamp.desk", new SymbolInfo("lamp.desk", "desk_lamp"));
			mappings.Add("flashlight.on.fill", new SymbolInfo("flashlight.on.fill", "flashlight_on"));
			mappings.Add("flashlight.off.fill", new SymbolInfo("flashlight.off.fill", "flashlight_off"));

			// Text Editing & Formatting
			mappings.Add("bold", new SymbolInfo("bold", "format_bold", false));
			mappings.Add("italic", new SymbolInfo("italic", "format_italic", false));
			mappings.Add("underline", new SymbolInfo("underline", "format_underlined", false));
			mappings.Add("strikethrough", new SymbolInfo("strikethrough", "format_strikethrough", false));
			mappings.Add("text.alignleft", new SymbolInfo("text.alignleft", "format_align_left", false));
			mappings.Add("text.aligncenter", new SymbolInfo("text.aligncenter", "format_align_center", false));
			mappings.Add("text.alignright", new SymbolInfo("text.alignright", "format_align_right", false));
			mappings.Add("text.justify", new SymbolInfo("text.justify", "format_align_justify", false));
			mappings.Add("list.bullet", new SymbolInfo("list.bullet", "format_list_bulleted", false));
			mappings.Add("list.number", new SymbolInfo("list.number", "format_list_numbered", false));
			mappings.Add("list.dash", new SymbolInfo("list.dash", "format_list_bulleted", false));
			mappings.Add("list.triangle", new SymbolInfo("list.triangle", "format_list_bulleted", false));
			mappings.Add("increase.indent", new SymbolInfo("increase.indent", "format_indent_increase", false));
			mappings.Add("decrease.indent", new SymbolInfo("decrease.indent", "format_indent_decrease", false));
			mappings.Add("increase.quotelevel", new SymbolInfo("increase.quotelevel", "format_quote", false));
			mappings.Add("decrease.quotelevel", new SymbolInfo("decrease.quotelevel", "format_quote", false));
			mappings.Add("paragraph", new SymbolInfo("paragraph", "format_paragraph", false));
			mappings.Add("textformat.size", new SymbolInfo("textformat.size", "format_size", false));
			mappings.Add("textformat.superscript", new SymbolInfo("textformat.superscript", "superscript", false));
			mappings.Add("textformat.subscript", new SymbolInfo("textformat.subscript", "subscript", false));
			mappings.Add("character.cursor.ibeam", new SymbolInfo("character.cursor.ibeam", "text_fields", false));
			mappings.Add("clear", new SymbolInfo("clear", "format_clear", false));
			mappings.Add("textformat", new SymbolInfo("textformat", "text_format", false));
			mappings.Add("textformat.abc", new SymbolInfo("textformat.abc", "spellcheck", false));
			mappings.Add("textformat.123", new SymbolInfo("textformat.123", "format_list_numbered", false));
			mappings.Add("character.magnify", new SymbolInfo("character.magnify", "zoom_in", false));
			mappings.Add("selection.pin.in.out", new SymbolInfo("selection.pin.in.out", "select_all", false));

			// Shapes & Symbols
			mappings.Add("circle", new SymbolInfo("circle", "circle"));
			mappings.Add("circle.fill", new SymbolInfo("circle.fill", "circle"));
			mappings.Add("largecircle.fill.circle", new SymbolInfo("largecircle.fill.circle", "radio_button_checked"));
			mappings.Add("circle.circle", new SymbolInfo("circle.circle", "radio_button_unchecked"));
			mappings.Add("smallcircle.fill.circle", new SymbolInfo("smallcircle.fill.circle", "fiber_manual_record"));
			mappings.Add("square", new SymbolInfo("square", "square"));
			mappings.Add("square.fill", new SymbolInfo("square.fill", "square"));
			mappings.Add("app", new SymbolInfo("app", "apps"));
			mappings.Add("rectangle", new SymbolInfo("rectangle", "rectangle", false));
			mappings.Add("rectangle.fill", new SymbolInfo("rectangle.fill", "rectangle"));
			mappings.Add("triangle", new SymbolInfo("triangle", "change_history", false));
			mappings.Add("triangle.fill", new SymbolInfo("triangle.fill", "change_history"));
			mappings.Add("diamond", new SymbolInfo("diamond", "diamond", false));
			mappings.Add("diamond.fill", new SymbolInfo("diamond.fill", "diamond"));

			// Transportation
			mappings.Add("car", new SymbolInfo("car", "directions_car"));
			mappings.Add("bus", new SymbolInfo("bus", "directions_bus"));
			mappings.Add("tram", new SymbolInfo("tram", "tram"));
			mappings.Add("airplane", new SymbolInfo("airplane", "flight"));
			mappings.Add("bicycle", new SymbolInfo("bicycle", "directions_bike"));
			mappings.Add("train.side.front.car", new SymbolInfo("train.side.front.car", "train"));
			mappings.Add("ferry", new SymbolInfo("ferry", "directions_boat"));
			mappings.Add("scooter", new SymbolInfo("scooter", "electric_scooter"));
			mappings.Add("figure.walk", new SymbolInfo("figure.walk", "directions_walk"));
			mappings.Add("figure.run", new SymbolInfo("figure.run", "directions_run"));
			mappings.Add("car.2", new SymbolInfo("car.2", "airport_shuttle"));
			mappings.Add("truck", new SymbolInfo("truck", "local_shipping"));
			mappings.Add("motorcycle", new SymbolInfo("motorcycle", "two_wheeler"));
			mappings.Add("sailboat", new SymbolInfo("sailboat", "sailing"));
			mappings.Add("parkingsign", new SymbolInfo("parkingsign", "local_parking"));
			mappings.Add("fuelpump", new SymbolInfo("fuelpump", "local_gas_station"));

			// Health & Fitness
			mappings.Add("heart.text.square", new SymbolInfo("heart.text.square", "medical_services"));
			mappings.Add("cross.case", new SymbolInfo("cross.case", "medical_services"));
			mappings.Add("stethoscope", new SymbolInfo("stethoscope", "health_and_safety"));
			mappings.Add("pills", new SymbolInfo("pills", "medication"));
			mappings.Add("syringe", new SymbolInfo("syringe", "vaccines"));
			mappings.Add("bandage", new SymbolInfo("bandage", "healing"));
			mappings.Add("thermometer", new SymbolInfo("thermometer", "device_thermostat"));
			mappings.Add("cross", new SymbolInfo("cross", "local_hospital"));
			mappings.Add("figure.strengthtraining.functional", new SymbolInfo("figure.strengthtraining.functional", "fitness_center"));
			mappings.Add("dumbbell", new SymbolInfo("dumbbell", "fitness_center"));
			mappings.Add("figure.yoga", new SymbolInfo("figure.yoga", "self_improvement"));
			mappings.Add("figure.mind.and.body", new SymbolInfo("figure.mind.and.body", "psychology"));
			mappings.Add("lungs", new SymbolInfo("lungs", "air"));
			mappings.Add("brain", new SymbolInfo("brain", "psychology"));
			mappings.Add("eye.square", new SymbolInfo("eye.square", "visibility"));
			mappings.Add("ear", new SymbolInfo("ear", "hearing"));
			mappings.Add("waveform.path.ecg", new SymbolInfo("waveform.path.ecg", "monitor_heart"));
			mappings.Add("allergens", new SymbolInfo("allergens", "coronavirus"));

			// Food & Dining
			mappings.Add("fork.knife", new SymbolInfo("fork.knife", "restaurant"));
			mappings.Add("cup.and.saucer", new SymbolInfo("cup.and.saucer", "local_cafe"));
			mappings.Add("wineglass", new SymbolInfo("wineglass", "local_bar"));
			mappings.Add("birthday.cake", new SymbolInfo("birthday.cake", "cake"));
			mappings.Add("apple.logo", new SymbolInfo("apple.logo", "apple"));
			mappings.Add("carrot", new SymbolInfo("carrot", "eco"));
			mappings.Add("fish", new SymbolInfo("fish", "set_meal"));
			mappings.Add("leaf.arrow.triangle.circlepath", new SymbolInfo("leaf.arrow.triangle.circlepath", "eco"));
			mappings.Add("takeoutbag.and.cup.and.straw", new SymbolInfo("takeoutbag.and.cup.and.straw", "takeout_dining"));
			mappings.Add("pizza", new SymbolInfo("pizza", "local_pizza"));
			mappings.Add("hamburger", new SymbolInfo("hamburger", "lunch_dining"));
			mappings.Add("popcorn", new SymbolInfo("popcorn", "movie"));
			mappings.Add("ice.cream", new SymbolInfo("ice.cream", "icecream"));
			mappings.Add("mug", new SymbolInfo("mug", "coffee"));
			mappings.Add("waterbottle", new SymbolInfo("waterbottle", "sports_bar"));

			// Shopping & Commerce
			mappings.Add("storefront", new SymbolInfo("storefront", "storefront"));
			mappings.Add("tag", new SymbolInfo("tag", "local_offer"));
			mappings.Add("percent.ar", new SymbolInfo("percent.ar", "percent"));
			mappings.Add("receipt", new SymbolInfo("receipt", "receipt"));
			mappings.Add("shippingbox", new SymbolInfo("shippingbox", "inventory_2"));
			mappings.Add("scale.3d", new SymbolInfo("scale.3d", "scale"));
			mappings.Add("basket", new SymbolInfo("basket", "shopping_basket"));
			mappings.Add("cart.badge.plus", new SymbolInfo("cart.badge.plus", "add_shopping_cart"));
			mappings.Add("cart.badge.minus", new SymbolInfo("cart.badge.minus", "remove_shopping_cart"));
			mappings.Add("bag.badge.plus", new SymbolInfo("bag.badge.plus", "add_shopping_cart"));
			mappings.Add("bag.badge.minus", new SymbolInfo("bag.badge.minus", "remove_shopping_cart"));
			mappings.Add("creditcard.and.123", new SymbolInfo("creditcard.and.123", "payment"));
			mappings.Add("building.2", new SymbolInfo("building.2", "business"));
			mappings.Add("building", new SymbolInfo("building", "apartment"));

			// Travel & Places
			mappings.Add("suitcase", new SymbolInfo("suitcase", "luggage"));
			mappings.Add("airplane.departure", new SymbolInfo("airplane.departure", "flight_takeoff"));
			mappings.Add("airplane.arrival", new SymbolInfo("airplane.arrival", "flight_land"));
			mappings.Add("bed.double.circle", new SymbolInfo("bed.double.circle", "hotel"));
			mappings.Add("building.columns", new SymbolInfo("building.columns", "account_balance"));
			mappings.Add("camera.macro.circle", new SymbolInfo("camera.macro.circle", "photo_camera"));
			mappings.Add("mountain.2", new SymbolInfo("mountain.2", "terrain"));
			mappings.Add("tree.circle", new SymbolInfo("tree.circle", "park"));
			mappings.Add("beach.umbrella", new SymbolInfo("beach.umbrella", "beach_access"));
			mappings.Add("snowcap.mountain", new SymbolInfo("snowcap.mountain", "downhill_skiing"));
			mappings.Add("tent", new SymbolInfo("tent", "camping"));
			mappings.Add("compass", new SymbolInfo("compass", "explore"));
			mappings.Add("signpost.right", new SymbolInfo("signpost.right", "signpost"));
			mappings.Add("ticket", new SymbolInfo("ticket", "confirmation_number"));
			mappings.Add("mappin", new SymbolInfo("mappin", "place"));
			mappings.Add("mappin.circle", new SymbolInfo("mappin.circle", "add_location"));
			mappings.Add("binoculars", new SymbolInfo("binoculars", "travel_explore"));

			// Entertainment & Gaming
			mappings.Add("dice", new SymbolInfo("dice", "casino"));
			mappings.Add("gamecontroller.fill", new SymbolInfo("gamecontroller.fill", "sports_esports"));
			mappings.Add("puzzlepiece", new SymbolInfo("puzzlepiece", "extension"));
			mappings.Add("party.popper", new SymbolInfo("party.popper", "celebration"));
			mappings.Add("balloon", new SymbolInfo("balloon", "celebration"));
			mappings.Add("movieclapper", new SymbolInfo("movieclapper", "movie"));
			mappings.Add("theatermasks", new SymbolInfo("theatermasks", "theater_comedy"));
			mappings.Add("tv.music.note", new SymbolInfo("tv.music.note", "music_video"));
			mappings.Add("guitars", new SymbolInfo("guitars", "library_music"));
			mappings.Add("music.note", new SymbolInfo("music.note", "music_note"));
			mappings.Add("music.quarternote.3", new SymbolInfo("music.quarternote.3", "queue_music"));
			mappings.Add("speaker.wave.3", new SymbolInfo("speaker.wave.3", "volume_up"));
			mappings.Add("hifispeaker.2", new SymbolInfo("hifispeaker.2", "speaker_group"));
			mappings.Add("guitars.fill", new SymbolInfo("guitars.fill", "piano"));

			// Education & Learning
			mappings.Add("graduationcap", new SymbolInfo("graduationcap", "school"));
			mappings.Add("book", new SymbolInfo("book", "menu_book"));
			mappings.Add("books.vertical", new SymbolInfo("books.vertical", "library_books"));
			mappings.Add("studentdesk", new SymbolInfo("studentdesk", "desk"));
			mappings.Add("backpack", new SymbolInfo("backpack", "backpack"));
			mappings.Add("pencil.and.ruler", new SymbolInfo("pencil.and.ruler", "architecture"));
			mappings.Add("ruler", new SymbolInfo("ruler", "straighten"));
			mappings.Add("triangle.and.line.vertical.and.triangle.fill", new SymbolInfo("triangle.and.line.vertical.and.triangle.fill", "functions"));
			mappings.Add("function", new SymbolInfo("function", "functions"));
			mappings.Add("x.squareroot", new SymbolInfo("x.squareroot", "calculate"));
			mappings.Add("sum", new SymbolInfo("sum", "calculate"));
			mappings.Add("chart.bar", new SymbolInfo("chart.bar", "bar_chart"));
			mappings.Add("chart.pie", new SymbolInfo("chart.pie", "pie_chart"));
			mappings.Add("chart.line.uptrend.xyaxis", new SymbolInfo("chart.line.uptrend.xyaxis", "trending_up"));
			mappings.Add("atom", new SymbolInfo("atom", "science"));
			mappings.Add("flask", new SymbolInfo("flask", "biotech"));
			mappings.Add("testtube.2", new SymbolInfo("testtube.2", "science"));

			// Business & Work
			mappings.Add("briefcase", new SymbolInfo("briefcase", "work"));
			mappings.Add("building.2.crop.circle", new SymbolInfo("building.2.crop.circle", "business_center"));
			mappings.Add("person.badge.shield.checkmark", new SymbolInfo("person.badge.shield.checkmark", "verified"));
			mappings.Add("signature", new SymbolInfo("signature", "draw"));
			mappings.Add("seal", new SymbolInfo("seal", "workspace_premium"));
			mappings.Add("doc.text.magnifyingglass", new SymbolInfo("doc.text.magnifyingglass", "search"));
			mappings.Add("folder.badge.person.crop", new SymbolInfo("folder.badge.person.crop", "folder_shared"));
			mappings.Add("tray.full", new SymbolInfo("tray.full", "inventory"));
			mappings.Add("archivebox.circle", new SymbolInfo("archivebox.circle", "archive"));
			mappings.Add("shredder", new SymbolInfo("shredder", "delete_forever"));
			mappings.Add("calendar.day.timeline.leading", new SymbolInfo("calendar.day.timeline.leading", "event_note"));
			mappings.Add("checklist", new SymbolInfo("checklist", "checklist"));
			mappings.Add("list.clipboard", new SymbolInfo("list.clipboard", "assignment"));

			// Social & Lifestyle
			mappings.Add("theatermasks.fill", new SymbolInfo("theatermasks.fill", "mood"));
			mappings.Add("figure.2.and.child.holdinghands", new SymbolInfo("figure.2.and.child.holdinghands", "family_restroom"));
			mappings.Add("figure.and.child.holdinghands", new SymbolInfo("figure.and.child.holdinghands", "escalator_warning"));
			mappings.Add("pawprint", new SymbolInfo("pawprint", "pets"));
			mappings.Add("dog", new SymbolInfo("dog", "pets"));
			mappings.Add("cat", new SymbolInfo("cat", "pets"));
			mappings.Add("bird", new SymbolInfo("bird", "pets"));
			mappings.Add("tortoise", new SymbolInfo("tortoise", "pets"));
			mappings.Add("hare", new SymbolInfo("hare", "pets"));
			mappings.Add("ladybug", new SymbolInfo("ladybug", "bug_report"));
			mappings.Add("ant", new SymbolInfo("ant", "bug_report"));
			mappings.Add("butterfly", new SymbolInfo("butterfly", "pets"));
			mappings.Add("lizard", new SymbolInfo("lizard", "pets"));

			// Sports & Recreation
			mappings.Add("football", new SymbolInfo("football", "sports_football"));
			mappings.Add("basketball", new SymbolInfo("basketball", "sports_basketball"));
			mappings.Add("baseball", new SymbolInfo("baseball", "sports_baseball"));
			mappings.Add("tennis.racket", new SymbolInfo("tennis.racket", "sports_tennis"));
			mappings.Add("soccerball", new SymbolInfo("soccerball", "sports_soccer"));
			mappings.Add("volleyball", new SymbolInfo("volleyball", "sports_volleyball"));
			mappings.Add("hockey.puck", new SymbolInfo("hockey.puck", "sports_hockey"));
			mappings.Add("cricket.ball", new SymbolInfo("cricket.ball", "sports_cricket"));
			mappings.Add("figure.skiing.downhill", new SymbolInfo("figure.skiing.downhill", "downhill_skiing"));
			mappings.Add("figure.snowboarding", new SymbolInfo("figure.snowboarding", "snowboarding"));
			mappings.Add("figure.pool.swim", new SymbolInfo("figure.pool.swim", "pool"));
			mappings.Add("figure.surfing", new SymbolInfo("figure.surfing", "surfing"));
			mappings.Add("trophy", new SymbolInfo("trophy", "emoji_events"));
			mappings.Add("medal", new SymbolInfo("medal", "military_tech"));
			mappings.Add("sportscourt", new SymbolInfo("sportscourt", "sports_tennis"));

			// Tools & Utilities
			mappings.Add("screwdriver", new SymbolInfo("screwdriver", "handyman"));
			mappings.Add("level", new SymbolInfo("level", "straighten"));
			mappings.Add("hammer.circle", new SymbolInfo("hammer.circle", "handyman"));
			mappings.Add("wrench.and.screwdriver", new SymbolInfo("wrench.and.screwdriver", "handyman"));
			mappings.Add("toolbox", new SymbolInfo("toolbox", "handyman"));
			mappings.Add("drill", new SymbolInfo("drill", "handyman"));
			mappings.Add("saw", new SymbolInfo("saw", "carpenter"));
			mappings.Add("ruler.fill", new SymbolInfo("ruler.fill", "straighten"));
			mappings.Add("cone", new SymbolInfo("cone", "construction"));
			mappings.Add("hard.hat", new SymbolInfo("hard.hat", "construction"));
			mappings.Add("ladder", new SymbolInfo("ladder", "handyman"));
			mappings.Add("paintbrush.pointed", new SymbolInfo("paintbrush.pointed", "format_paint"));
			mappings.Add("eyedropper", new SymbolInfo("eyedropper", "colorize"));
			mappings.Add("lasso", new SymbolInfo("lasso", "gesture"));

			// Science & Technology
			mappings.Add("scope", new SymbolInfo("scope", "search"));
			mappings.Add("microscope", new SymbolInfo("microscope", "biotech"));
			mappings.Add("telescope", new SymbolInfo("telescope", "center_focus_strong"));
			mappings.Add("safari", new SymbolInfo("safari", "explore"));
			mappings.Add("globe.central.south.asia", new SymbolInfo("globe.central.south.asia", "public"));
			mappings.Add("safari.fill", new SymbolInfo("safari.fill", "travel_explore"));
			mappings.Add("server.rack", new SymbolInfo("server.rack", "dns"));
			mappings.Add("externaldrive.connected.to.line.below", new SymbolInfo("externaldrive.connected.to.line.below", "storage"));
			mappings.Add("location.magnifyingglass", new SymbolInfo("location.magnifyingglass", "search"));
			mappings.Add("wifi.router", new SymbolInfo("wifi.router", "router"));

			mappings.Add("wave.3.left", new SymbolInfo("wave.3.left", "graphic_eq"));
			mappings.Add("waveform", new SymbolInfo("waveform", "equalizer"));

			// Arts & Design
			mappings.Add("paintpalette", new SymbolInfo("paintpalette", "palette"));
			mappings.Add("camera.filters", new SymbolInfo("camera.filters", "photo_filter"));
			mappings.Add("camera.aperture", new SymbolInfo("camera.aperture", "camera"));
			mappings.Add("viewfinder.circle", new SymbolInfo("viewfinder.circle", "camera_alt"));
			mappings.Add("rectangle.3.group", new SymbolInfo("rectangle.3.group", "view_module"));
			mappings.Add("square.grid.2x2", new SymbolInfo("square.grid.2x2", "grid_view"));
			mappings.Add("square.grid.3x3", new SymbolInfo("square.grid.3x3", "apps"));
			mappings.Add("circle.grid.2x2", new SymbolInfo("circle.grid.2x2", "apps"));
			mappings.Add("hexagon", new SymbolInfo("hexagon", "hexagon", false));
			mappings.Add("oval", new SymbolInfo("oval", "circle"));
			mappings.Add("rhombus", new SymbolInfo("rhombus", "diamond"));
			mappings.Add("octagon", new SymbolInfo("octagon", "stop"));
			mappings.Add("pentagon", new SymbolInfo("pentagon", "pentagon"));
			mappings.Add("capsule", new SymbolInfo("capsule", "label"));

			// Weather & Climate (Extended)
			mappings.Add("sun.haze", new SymbolInfo("sun.haze", "wb_sunny"));
			mappings.Add("cloud.drizzle", new SymbolInfo("cloud.drizzle", "grain"));
			mappings.Add("cloud.heavyrain", new SymbolInfo("cloud.heavyrain", "thunderstorm"));
			mappings.Add("cloud.sleet", new SymbolInfo("cloud.sleet", "snowy"));
			mappings.Add("cloud.hail", new SymbolInfo("cloud.hail", "ac_unit"));
			mappings.Add("cloud.fog", new SymbolInfo("cloud.fog", "foggy"));
			mappings.Add("smoke", new SymbolInfo("smoke", "smoking_rooms"));
			mappings.Add("aqi.low", new SymbolInfo("aqi.low", "air"));
			mappings.Add("aqi.medium", new SymbolInfo("aqi.medium", "air"));
			mappings.Add("aqi.high", new SymbolInfo("aqi.high", "air"));
			mappings.Add("thermometer.snowflake", new SymbolInfo("thermometer.snowflake", "ac_unit"));
			mappings.Add("thermometer.variable", new SymbolInfo("thermometer.variable", "device_thermostat"));
			mappings.Add("umbrella", new SymbolInfo("umbrella", "beach_access"));
			mappings.Add("rainbow", new SymbolInfo("rainbow", "filter_vintage"));

			// Communication & Social Media
			mappings.Add("bubble.left.and.exclamationmark.bubble.right", new SymbolInfo("bubble.left.and.exclamationmark.bubble.right", "priority_high"));
			mappings.Add("at.badge.plus", new SymbolInfo("at.badge.plus", "add"));
			mappings.Add("at.badge.minus", new SymbolInfo("at.badge.minus", "remove"));
			mappings.Add("message.circle", new SymbolInfo("message.circle", "chat"));
			mappings.Add("message.and.waveform", new SymbolInfo("message.and.waveform", "voice_chat"));
			mappings.Add("phone.fill.arrow.up.right", new SymbolInfo("phone.fill.arrow.up.right", "call_made"));
			mappings.Add("phone.fill.arrow.down.left", new SymbolInfo("phone.fill.arrow.down.left", "call_received"));
			mappings.Add("video.badge.plus", new SymbolInfo("video.badge.plus", "video_call"));
			mappings.Add("facetime", new SymbolInfo("facetime", "video_call"));
			mappings.Add("shareplay", new SymbolInfo("shareplay", "screen_share"));
			mappings.Add("location.viewfinder", new SymbolInfo("location.viewfinder", "gps_fixed"));
			mappings.Add("link.badge.plus", new SymbolInfo("link.badge.plus", "add_link"));
			mappings.Add("megaphone", new SymbolInfo("megaphone", "campaign"));
			mappings.Add("speaker.badge.exclamationmark", new SymbolInfo("speaker.badge.exclamationmark", "volume_up"));
			mappings.Add("hands.clap", new SymbolInfo("hands.clap", "emoji_emotions"));

			// File Types & Documents
			mappings.Add("doc.fill", new SymbolInfo("doc.fill", "description"));
			mappings.Add("doc.text", new SymbolInfo("doc.text", "article"));
			mappings.Add("doc.plaintext", new SymbolInfo("doc.plaintext", "text_snippet"));
			mappings.Add("doc.richtext", new SymbolInfo("doc.richtext", "text_format"));
			mappings.Add("doc.zip", new SymbolInfo("doc.zip", "folder_zip"));
			mappings.Add("doc.pdf", new SymbolInfo("doc.pdf", "picture_as_pdf"));
			mappings.Add("photo.artframe", new SymbolInfo("photo.artframe", "image"));
			mappings.Add("video.square", new SymbolInfo("video.square", "video_file"));
			mappings.Add("music.note.house", new SymbolInfo("music.note.house", "audio_file"));
			mappings.Add("tablecells", new SymbolInfo("tablecells", "table_chart"));
			mappings.Add("chart.xyaxis.line", new SymbolInfo("chart.xyaxis.line", "show_chart"));
			mappings.Add("waveform.circle", new SymbolInfo("waveform.circle", "graphic_eq"));
			mappings.Add("code", new SymbolInfo("code", "code"));
			mappings.Add("curlybraces", new SymbolInfo("curlybraces", "data_object"));
			mappings.Add("chevron.left.forwardslash.chevron.right", new SymbolInfo("chevron.left.forwardslash.chevron.right", "code"));

			// UI/UX Elements
			mappings.Add("rectangle.split.3x1", new SymbolInfo("rectangle.split.3x1", "view_column"));
			mappings.Add("rectangle.split.1x2", new SymbolInfo("rectangle.split.1x2", "vertical_split"));
			mappings.Add("rectangle.split.2x1", new SymbolInfo("rectangle.split.2x1", "horizontal_split"));
			mappings.Add("sidebar.left", new SymbolInfo("sidebar.left", "view_sidebar"));
			mappings.Add("sidebar.right", new SymbolInfo("sidebar.right", "view_sidebar"));
			mappings.Add("macwindow", new SymbolInfo("macwindow", "web_asset"));
			mappings.Add("dock.rectangle", new SymbolInfo("dock.rectangle", "dock"));
			mappings.Add("menubar.rectangle", new SymbolInfo("menubar.rectangle", "menu"));
			mappings.Add("uiwindow.split.2x1", new SymbolInfo("uiwindow.split.2x1", "view_quilt"));
			mappings.Add("rectangle.grid.1x2", new SymbolInfo("rectangle.grid.1x2", "view_agenda"));
			mappings.Add("square.grid.4x3.fill", new SymbolInfo("square.grid.4x3.fill", "grid_on"));
			mappings.Add("rectangle.on.rectangle", new SymbolInfo("rectangle.on.rectangle", "layers"));
			mappings.Add("square.stack", new SymbolInfo("square.stack", "layers"));
			mappings.Add("circle.inset.filled", new SymbolInfo("circle.inset.filled", "radio_button_checked"));
			mappings.Add("checkmark.square", new SymbolInfo("checkmark.square", "check_box"));


			// Accessibility
			mappings.Add("accessibility", new SymbolInfo("accessibility", "accessibility"));
			mappings.Add("figure.roll", new SymbolInfo("figure.roll", "accessible"));
			mappings.Add("ear.badge.checkmark", new SymbolInfo("ear.badge.checkmark", "hearing"));
			mappings.Add("ear.trianglebadge.exclamationmark", new SymbolInfo("ear.trianglebadge.exclamationmark", "hearing_disabled"));
			mappings.Add("eye.trianglebadge.exclamationmark", new SymbolInfo("eye.trianglebadge.exclamationmark", "visibility_off"));
			mappings.Add("hand.point.up.braille", new SymbolInfo("hand.point.up.braille", "touch_app"));
			mappings.Add("textformat.size.larger", new SymbolInfo("textformat.size.larger", "zoom_in"));
			mappings.Add("textformat.size.smaller", new SymbolInfo("textformat.size.smaller", "zoom_out"));
			mappings.Add("moonphase.first.quarter", new SymbolInfo("moonphase.first.quarter", "contrast"));
			mappings.Add("circle.lefthalf.striped.horizontal", new SymbolInfo("circle.lefthalf.striped.horizontal", "contrast"));
			mappings.Add("speaker.zzz", new SymbolInfo("speaker.zzz", "volume_off"));
			mappings.Add("text.magnifyingglass", new SymbolInfo("text.magnifyingglass", "search"));

			// Geographic & Nature
			mappings.Add("mountain.range", new SymbolInfo("mountain.range", "landscape"));
			mappings.Add("water.waves", new SymbolInfo("water.waves", "waves"));
			mappings.Add("beach.umbrella.fill", new SymbolInfo("beach.umbrella.fill", "beach_access"));
			mappings.Add("desert", new SymbolInfo("desert", "landscape"));
			mappings.Add("forest", new SymbolInfo("forest", "forest"));

			mappings.Add("cactus", new SymbolInfo("cactus", "eco"));
			mappings.Add("coral.fill", new SymbolInfo("coral.fill", "eco"));
			mappings.Add("fish.fill", new SymbolInfo("fish.fill", "set_meal"));
			mappings.Add("ladybug.fill", new SymbolInfo("ladybug.fill", "bug_report"));
			mappings.Add("lizard.fill", new SymbolInfo("lizard.fill", "pets"));
			mappings.Add("bird.fill", new SymbolInfo("bird.fill", "pets"));
			mappings.Add("ant.fill", new SymbolInfo("ant.fill", "bug_report"));
			mappings.Add("tortoise.fill", new SymbolInfo("tortoise.fill", "pets"));
			mappings.Add("hare.fill", new SymbolInfo("hare.fill", "pets"));

			// Finance & Banking
			mappings.Add("building.columns.fill", new SymbolInfo("building.columns.fill", "account_balance"));
			mappings.Add("creditcard.fill", new SymbolInfo("creditcard.fill", "credit_card"));
			mappings.Add("banknote.fill", new SymbolInfo("banknote.fill", "attach_money"));
			mappings.Add("dollarsign.arrow.circlepath", new SymbolInfo("dollarsign.arrow.circlepath", "currency_exchange"));
			mappings.Add("eurosign.circle", new SymbolInfo("eurosign.circle", "euro"));
			mappings.Add("yensign.circle", new SymbolInfo("yensign.circle", "currency_yen"));
			mappings.Add("sterlingsign.circle", new SymbolInfo("sterlingsign.circle", "currency_pound"));
			mappings.Add("bitcoinsign.circle", new SymbolInfo("bitcoinsign.circle", "currency_bitcoin"));
			mappings.Add("chart.line.uptrend.xyaxis.circle", new SymbolInfo("chart.line.uptrend.xyaxis.circle", "trending_up"));
			mappings.Add("chart.line.downtrend.xyaxis", new SymbolInfo("chart.line.downtrend.xyaxis", "trending_down"));
			mappings.Add("indianrupeesign.circle", new SymbolInfo("indianrupeesign.circle", "currency_rupee"));
			mappings.Add("wallet.pass", new SymbolInfo("wallet.pass", "account_balance_wallet"));
			mappings.Add("creditcard.trianglebadge.exclamationmark", new SymbolInfo("creditcard.trianglebadge.exclamationmark", "credit_card_off"));
			mappings.Add("building.2.fill", new SymbolInfo("building.2.fill", "business"));

			// Medical & Healthcare (Extended)
			mappings.Add("cross.fill", new SymbolInfo("cross.fill", "local_hospital"));
			mappings.Add("medical.thermometer", new SymbolInfo("medical.thermometer", "device_thermostat"));
			mappings.Add("pill", new SymbolInfo("pill", "medication"));
			mappings.Add("ivfluid.bag", new SymbolInfo("ivfluid.bag", "medical_services"));
			mappings.Add("cross.vial", new SymbolInfo("cross.vial", "science"));
			mappings.Add("heart.circle", new SymbolInfo("heart.circle", "favorite"));
			mappings.Add("heart.slash", new SymbolInfo("heart.slash", "heart_broken"));
			mappings.Add("lungs.fill", new SymbolInfo("lungs.fill", "air"));
			mappings.Add("brain.head.profile", new SymbolInfo("brain.head.profile", "psychology"));
			mappings.Add("eye.circle.fill", new SymbolInfo("eye.circle.fill", "visibility"));
			mappings.Add("ear.fill", new SymbolInfo("ear.fill", "hearing"));
			mappings.Add("nose", new SymbolInfo("nose", "self_improvement"));
			mappings.Add("mouth", new SymbolInfo("mouth", "record_voice_over"));
			mappings.Add("tooth", new SymbolInfo("tooth", "medical_services"));
			mappings.Add("bandage.fill", new SymbolInfo("bandage.fill", "healing"));

			// Home & Living
			mappings.Add("house.fill", new SymbolInfo("house.fill", "home"));
			mappings.Add("house.lodge", new SymbolInfo("house.lodge", "cabin"));
			mappings.Add("building.fill", new SymbolInfo("building.fill", "apartment"));
			mappings.Add("sofa", new SymbolInfo("sofa", "weekend"));
			mappings.Add("chair", new SymbolInfo("chair", "chair"));
			mappings.Add("bed.double.fill", new SymbolInfo("bed.double.fill", "bed"));
			mappings.Add("bathtub", new SymbolInfo("bathtub", "bathtub"));
			mappings.Add("shower", new SymbolInfo("shower", "shower"));
			mappings.Add("refrigerator", new SymbolInfo("refrigerator", "kitchen"));
			mappings.Add("oven", new SymbolInfo("oven", "oven"));
			mappings.Add("microwave", new SymbolInfo("microwave", "microwave"));
			mappings.Add("dishwasher", new SymbolInfo("dishwasher", "dishwasher"));
			mappings.Add("washer", new SymbolInfo("washer", "local_laundry_service"));
			mappings.Add("dryer", new SymbolInfo("dryer", "local_laundry_service"));
			mappings.Add("air.conditioner.horizontal", new SymbolInfo("air.conditioner.horizontal", "ac_unit"));
			mappings.Add("fan", new SymbolInfo("fan", "wind_power"));
			mappings.Add("heater", new SymbolInfo("heater", "heat_pump"));
			mappings.Add("fireplace", new SymbolInfo("fireplace", "fireplace"));
			mappings.Add("door.left.hand.open", new SymbolInfo("door.left.hand.open", "door_front"));
			mappings.Add("window.horizontal", new SymbolInfo("window.horizontal", "window"));

			// Security & Authentication (Extended)
			mappings.Add("lock.fill", new SymbolInfo("lock.fill", "lock"));
			mappings.Add("lock.open.fill", new SymbolInfo("lock.open.fill", "lock_open"));
			mappings.Add("key.fill", new SymbolInfo("key.fill", "vpn_key"));
			mappings.Add("shield.fill", new SymbolInfo("shield.fill", "shield"));
			mappings.Add("shield.lefthalf.fill", new SymbolInfo("shield.lefthalf.fill", "verified_user"));
			mappings.Add("checkmark.shield.fill", new SymbolInfo("checkmark.shield.fill", "verified"));
			mappings.Add("xmark.shield.fill", new SymbolInfo("xmark.shield.fill", "gpp_bad"));
			mappings.Add("lock.shield.fill", new SymbolInfo("lock.shield.fill", "enhanced_encryption"));
			mappings.Add("person.badge.key.fill", new SymbolInfo("person.badge.key.fill", "admin_panel_settings"));
			mappings.Add("key.horizontal", new SymbolInfo("key.horizontal", "vpn_key"));
			mappings.Add("key.radiowaves.forward", new SymbolInfo("key.radiowaves.forward", "wifi_protected_setup"));
			mappings.Add("qrcode", new SymbolInfo("qrcode", "qr_code"));
			mappings.Add("barcode", new SymbolInfo("barcode", "qr_code_scanner"));
			mappings.Add("camera.badge.ellipsis", new SymbolInfo("camera.badge.ellipsis", "camera_enhance"));

			// Data & Analytics
			mappings.Add("chart.bar.fill", new SymbolInfo("chart.bar.fill", "bar_chart"));
			mappings.Add("chart.pie.fill", new SymbolInfo("chart.pie.fill", "pie_chart"));
			mappings.Add("chart.dots.scatter", new SymbolInfo("chart.dots.scatter", "scatter_plot"));
			mappings.Add("waveform.path", new SymbolInfo("waveform.path", "equalizer"));
			mappings.Add("waveform.path.ecg.rectangle", new SymbolInfo("waveform.path.ecg.rectangle", "monitor"));
			mappings.Add("point.3.connected.trianglepath.dotted", new SymbolInfo("point.3.connected.trianglepath.dotted", "scatter_plot"));
			mappings.Add("database", new SymbolInfo("database", "storage"));
			mappings.Add("server.rack.fill", new SymbolInfo("server.rack.fill", "dns"));
			mappings.Add("cpu.fill", new SymbolInfo("cpu.fill", "developer_board"));
			mappings.Add("memorychip.fill", new SymbolInfo("memorychip.fill", "memory"));
			mappings.Add("chart.bar.doc.horizontal", new SymbolInfo("chart.bar.doc.horizontal", "analytics"));
			mappings.Add("tablecells.fill", new SymbolInfo("tablecells.fill", "table_chart"));

			// Development & Code
			mappings.Add("terminal", new SymbolInfo("terminal", "terminal"));
			mappings.Add("terminal.fill", new SymbolInfo("terminal.fill", "terminal"));
			mappings.Add("chevron.left.slash.chevron.right", new SymbolInfo("chevron.left.slash.chevron.right", "code"));
			mappings.Add("curlybraces.square", new SymbolInfo("curlybraces.square", "integration_instructions"));
			mappings.Add("function.fill", new SymbolInfo("function.fill", "functions"));
			mappings.Add("fx", new SymbolInfo("fx", "functions"));
			mappings.Add("sum.fill", new SymbolInfo("sum.fill", "calculate"));
			mappings.Add("x.squareroot.fill", new SymbolInfo("x.squareroot.fill", "calculate"));
			mappings.Add("percent.fill", new SymbolInfo("percent.fill", "percent"));
			mappings.Add("number.fill", new SymbolInfo("number.fill", "tag"));
			mappings.Add("at.fill", new SymbolInfo("at.fill", "alternate_email"));
			mappings.Add("questionmark.fill", new SymbolInfo("questionmark.fill", "help"));
			mappings.Add("exclamationmark.fill", new SymbolInfo("exclamationmark.fill", "priority_high"));
			mappings.Add("ant.circle", new SymbolInfo("ant.circle", "bug_report"));
			mappings.Add("ladybug.circle", new SymbolInfo("ladybug.circle", "bug_report"));

			// Emotions & Expressions
			mappings.Add("face.smiling", new SymbolInfo("face.smiling", "sentiment_very_satisfied"));
			mappings.Add("face.dashed", new SymbolInfo("face.dashed", "sentiment_neutral"));
			mappings.Add("hand.thumbsup", new SymbolInfo("hand.thumbsup", "thumb_up"));
			mappings.Add("hand.thumbsdown", new SymbolInfo("hand.thumbsdown", "thumb_down"));
			mappings.Add("hand.wave", new SymbolInfo("hand.wave", "waving_hand"));
			mappings.Add("hands.sparkles", new SymbolInfo("hands.sparkles", "auto_awesome"));
			mappings.Add("heart.fill", new SymbolInfo("heart.fill", "favorite"));
			mappings.Add("heart.slash.fill", new SymbolInfo("heart.slash.fill", "heart_broken"));
			mappings.Add("star.fill", new SymbolInfo("star.fill", "star"));
			mappings.Add("sparkles.rectangle.stack", new SymbolInfo("sparkles.rectangle.stack", "auto_awesome"));
			mappings.Add("moon.stars.fill", new SymbolInfo("moon.stars.fill", "bedtime"));
			mappings.Add("sun.dust.fill", new SymbolInfo("sun.dust.fill", "wb_sunny"));
			mappings.Add("cloud.fill", new SymbolInfo("cloud.fill", "cloud"));
			mappings.Add("drop.fill", new SymbolInfo("drop.fill", "water_drop"));
			mappings.Add("flame.fill", new SymbolInfo("flame.fill", "local_fire_department"));

			// International & Languages
			mappings.Add("flag", new SymbolInfo("flag", "flag"));
			mappings.Add("flag.fill", new SymbolInfo("flag.fill", "flag"));
			mappings.Add("flag.checkered", new SymbolInfo("flag.checkered", "sports_motorsports"));
			mappings.Add("globe.badge.chevron.backward", new SymbolInfo("globe.badge.chevron.backward", "translate"));
			mappings.Add("globe.desk", new SymbolInfo("globe.desk", "language"));
			mappings.Add("character.book.closed", new SymbolInfo("character.book.closed", "translate"));
			mappings.Add("a.book.closed", new SymbolInfo("a.book.closed", "spellcheck"));
			mappings.Add("textformat.alt", new SymbolInfo("textformat.alt", "text_format"));
			mappings.Add("character.duployan", new SymbolInfo("character.duployan", "language"));
			mappings.Add("character.phonetic", new SymbolInfo("character.phonetic", "record_voice_over"));
			mappings.Add("character.textbox", new SymbolInfo("character.textbox", "text_fields"));
			mappings.Add("translate", new SymbolInfo("translate", "translate"));
			mappings.Add("moon.zzz", new SymbolInfo("moon.zzz", "bedtime"));
			mappings.Add("sun.and.horizon", new SymbolInfo("sun.and.horizon", "wb_twilight"));

			// Military & Defense
			mappings.Add("shield.righthalf.filled", new SymbolInfo("shield.righthalf.filled", "security"));
			mappings.Add("target", new SymbolInfo("target", "gps_fixed"));
			mappings.Add("scope.crosshairs", new SymbolInfo("scope.crosshairs", "my_location"));
			mappings.Add("boomerang", new SymbolInfo("boomerang", "360"));
			mappings.Add("airplane.circle", new SymbolInfo("airplane.circle", "flight"));
			mappings.Add("helicopter", new SymbolInfo("helicopter", "flight"));
			mappings.Add("sailboat.fill", new SymbolInfo("sailboat.fill", "sailing"));
			mappings.Add("ferry.fill", new SymbolInfo("ferry.fill", "directions_boat"));
			mappings.Add("binoculars.fill", new SymbolInfo("binoculars.fill", "search"));
			mappings.Add("location.slash", new SymbolInfo("location.slash", "location_disabled"));
			mappings.Add("location.fill.viewfinder", new SymbolInfo("location.fill.viewfinder", "gps_fixed"));
			mappings.Add("flashlight.slash", new SymbolInfo("flashlight.slash", "flashlight_off"));

			// Religion & Spirituality
			mappings.Add("cross.case.fill", new SymbolInfo("cross.case.fill", "church"));
			mappings.Add("leaf.circle", new SymbolInfo("leaf.circle", "eco_circle"));
			mappings.Add("moon.circle", new SymbolInfo("moon.circle", "brightness_2"));
			mappings.Add("sun.max.circle", new SymbolInfo("sun.max.circle", "wb_sunny"));
			mappings.Add("star.circle", new SymbolInfo("star.circle", "star"));
			mappings.Add("hand.raised.circle", new SymbolInfo("hand.raised.circle", "pan_tool"));
			mappings.Add("hands.and.sparkles", new SymbolInfo("hands.and.sparkles", "volunteer_activism"));

			mappings.Add("heart.circle.fill", new SymbolInfo("heart.circle.fill", "favorite"));
			mappings.Add("hands.clap.fill", new SymbolInfo("hands.clap.fill", "celebration"));

			// Agriculture & Farming
			mappings.Add("leaf.arrow.circlepath", new SymbolInfo("leaf.arrow.circlepath", "recycling"));
			mappings.Add("drop.triangle", new SymbolInfo("drop.triangle", "water_drop"));
			mappings.Add("sun.rain", new SymbolInfo("sun.rain", "partly_cloudy_day"));
			mappings.Add("cloud.sun.rain", new SymbolInfo("cloud.sun.rain", "partly_cloudy_day"));
			mappings.Add("thermometer.medium", new SymbolInfo("thermometer.medium", "device_thermostat"));
			mappings.Add("humidity.fill", new SymbolInfo("humidity.fill", "humidity_percentage"));
			mappings.Add("wind.snow", new SymbolInfo("wind.snow", "severe_cold"));
			mappings.Add("tornado.circle", new SymbolInfo("tornado.circle", "cyclone"));
			mappings.Add("hurricane.circle", new SymbolInfo("hurricane.circle", "cyclone"));
			mappings.Add("tree.fill", new SymbolInfo("tree.fill", "park"));
			mappings.Add("flower", new SymbolInfo("flower", "local_florist"));
			mappings.Add("seedling", new SymbolInfo("seedling", "eco"));

			// Industrial & Manufacturing
			mappings.Add("gearshape", new SymbolInfo("gearshape", "settings"));
			mappings.Add("gearshape.fill", new SymbolInfo("gearshape.fill", "settings"));
			mappings.Add("gearshape.2", new SymbolInfo("gearshape.2", "engineering"));
			mappings.Add("gearshape.2.fill", new SymbolInfo("gearshape.2.fill", "engineering"));
			mappings.Add("wrench.adjustable", new SymbolInfo("wrench.adjustable", "build"));
			mappings.Add("wrench.adjustable.fill", new SymbolInfo("wrench.adjustable.fill", "build"));
			mappings.Add("hammer.fill", new SymbolInfo("hammer.fill", "construction"));
			mappings.Add("screwdriver.fill", new SymbolInfo("screwdriver.fill", "handyman"));
			mappings.Add("wrench.and.screwdriver.fill", new SymbolInfo("wrench.and.screwdriver.fill", "handyman"));
			mappings.Add("toolbox.fill", new SymbolInfo("toolbox.fill", "handyman"));
			mappings.Add("building.2.crop.circle.fill", new SymbolInfo("building.2.crop.circle.fill", "factory"));
			mappings.Add("smokestack", new SymbolInfo("smokestack", "factory"));
			mappings.Add("crane", new SymbolInfo("crane", "construction"));
			mappings.Add("truck.box", new SymbolInfo("truck.box", "local_shipping"));

			// Space & Astronomy
			mappings.Add("moon.phase.first.quarter", new SymbolInfo("moon.phase.first.quarter", "brightness_2"));
			mappings.Add("moon.phase.full", new SymbolInfo("moon.phase.full", "brightness_2"));
			mappings.Add("moon.phase.last.quarter", new SymbolInfo("moon.phase.last.quarter", "brightness_2"));
			mappings.Add("moon.phase.new", new SymbolInfo("moon.phase.new", "brightness_1"));
			mappings.Add("sparkle", new SymbolInfo("sparkle", "auto_awesome"));
			mappings.Add("sparkles.tv", new SymbolInfo("sparkles.tv", "auto_awesome"));
			mappings.Add("sun.horizon", new SymbolInfo("sun.horizon", "wb_twilight"));
			mappings.Add("sun.horizon.fill", new SymbolInfo("sun.horizon.fill", "wb_twilight"));
			mappings.Add("moon.haze", new SymbolInfo("moon.haze", "foggy"));
			mappings.Add("star.leadinghalf.filled", new SymbolInfo("star.leadinghalf.filled", "star_half"));
			mappings.Add("star.square", new SymbolInfo("star.square", "star"));
			mappings.Add("star.square.fill", new SymbolInfo("star.square.fill", "star"));
			mappings.Add("moon.zzz.fill", new SymbolInfo("moon.zzz.fill", "bedtime"));
			mappings.Add("sparkles.square.filled.on.square", new SymbolInfo("sparkles.square.filled.on.square", "auto_awesome"));

			// Music & Audio (Extended)
			mappings.Add("music.mic", new SymbolInfo("music.mic", "mic"));
			mappings.Add("music.note.list", new SymbolInfo("music.note.list", "queue_music"));
			mappings.Add("waveform.badge.plus", new SymbolInfo("waveform.badge.plus", "graphic_eq"));
			mappings.Add("waveform.badge.minus", new SymbolInfo("waveform.badge.minus", "graphic_eq"));
			mappings.Add("waveform.circle.fill", new SymbolInfo("waveform.circle.fill", "graphic_eq"));
			mappings.Add("speaker.plus", new SymbolInfo("speaker.plus", "volume_up"));
			mappings.Add("speaker.minus", new SymbolInfo("speaker.minus", "volume_down"));
			mappings.Add("speaker.circle", new SymbolInfo("speaker.circle", "volume_up"));
			mappings.Add("speaker.circle.fill", new SymbolInfo("speaker.circle.fill", "volume_up"));
			mappings.Add("airpods.gen3", new SymbolInfo("airpods.gen3", "headphones"));
			mappings.Add("airpodsmax", new SymbolInfo("airpodsmax", "headphones"));
			mappings.Add("homepod.and.homepodmini", new SymbolInfo("homepod.and.homepodmini", "speaker_group"));
			mappings.Add("radio.fill", new SymbolInfo("radio.fill", "radio"));


			// Photography & Camera (Extended)
			mappings.Add("camera.circle", new SymbolInfo("camera.circle", "camera_alt"));
			mappings.Add("camera.circle.fill", new SymbolInfo("camera.circle.fill", "camera_alt"));
			mappings.Add("camera.on.rectangle", new SymbolInfo("camera.on.rectangle", "photo_camera"));
			mappings.Add("camera.on.rectangle.fill", new SymbolInfo("camera.on.rectangle.fill", "photo_camera"));
			mappings.Add("camera.metering.center.weighted.average", new SymbolInfo("camera.metering.center.weighted.average", "center_focus_strong"));
			mappings.Add("camera.metering.center.weighted", new SymbolInfo("camera.metering.center.weighted", "center_focus_weak"));
			mappings.Add("camera.metering.matrix", new SymbolInfo("camera.metering.matrix", "grid_on"));
			mappings.Add("camera.metering.multispot", new SymbolInfo("camera.metering.multispot", "scatter_plot"));
			mappings.Add("camera.metering.none", new SymbolInfo("camera.metering.none", "center_focus_strong"));
			mappings.Add("camera.metering.partial", new SymbolInfo("camera.metering.partial", "center_focus_weak"));
			mappings.Add("camera.metering.spot", new SymbolInfo("camera.metering.spot", "my_location"));
			mappings.Add("camera.metering.unknown", new SymbolInfo("camera.metering.unknown", "help"));
			mappings.Add("flashlight.on.circle", new SymbolInfo("flashlight.on.circle", "flashlight_on"));
			mappings.Add("flashlight.off.circle", new SymbolInfo("flashlight.off.circle", "flashlight_off"));

			// Gaming & Entertainment (Extended)
			mappings.Add("dice.fill", new SymbolInfo("dice.fill", "casino"));
			mappings.Add("crown.fill", new SymbolInfo("crown.fill", "workspace_premium"));
			mappings.Add("trophy.fill", new SymbolInfo("trophy.fill", "emoji_events"));
			mappings.Add("medal.fill", new SymbolInfo("medal.fill", "military_tech"));
			mappings.Add("gift.fill", new SymbolInfo("gift.fill", "card_giftcard"));
			mappings.Add("party.popper.fill", new SymbolInfo("party.popper.fill", "celebration"));
			mappings.Add("balloon.fill", new SymbolInfo("balloon.fill", "celebration"));
			mappings.Add("theatermask.and.paintbrush", new SymbolInfo("theatermask.and.paintbrush", "theater_comedy"));
			mappings.Add("ticket.fill", new SymbolInfo("ticket.fill", "confirmation_number"));
			mappings.Add("popcorn.fill", new SymbolInfo("popcorn.fill", "movie"));
			mappings.Add("tv.circle", new SymbolInfo("tv.circle", "tv"));
			mappings.Add("tv.circle.fill", new SymbolInfo("tv.circle.fill", "tv"));

			// Legal & Government
			mappings.Add("building.columns.circle", new SymbolInfo("building.columns.circle", "account_balance"));
			mappings.Add("building.columns.circle.fill", new SymbolInfo("building.columns.circle.fill", "account_balance"));
			mappings.Add("scale", new SymbolInfo("scale", "balance"));
			mappings.Add("scale.fill", new SymbolInfo("scale.fill", "balance"));
			mappings.Add("signature.fill", new SymbolInfo("signature.fill", "draw"));
			mappings.Add("seal.fill", new SymbolInfo("seal.fill", "workspace_premium"));
			mappings.Add("doc.badge.gearshape", new SymbolInfo("doc.badge.gearshape", "policy"));
			mappings.Add("doc.badge.gearshape.fill", new SymbolInfo("doc.badge.gearshape.fill", "policy"));
			mappings.Add("folder.badge.gearshape", new SymbolInfo("folder.badge.gearshape", "folder_managed"));
			mappings.Add("folder.badge.gearshape.fill", new SymbolInfo("folder.badge.gearshape.fill", "folder_managed"));
			mappings.Add("person.text.rectangle.fill", new SymbolInfo("person.text.rectangle.fill", "badge"));
			mappings.Add("person.badge.shield.checkmark.fill", new SymbolInfo("person.badge.shield.checkmark.fill", "verified"));

			// Emergency & Safety
			mappings.Add("cross.circle", new SymbolInfo("cross.circle", "local_hospital"));
			mappings.Add("cross.circle.fill", new SymbolInfo("cross.circle.fill", "local_hospital"));
			mappings.Add("flame.circle", new SymbolInfo("flame.circle", "local_fire_department"));
			mappings.Add("flame.circle.fill", new SymbolInfo("flame.circle.fill", "local_fire_department"));
			mappings.Add("car.circle", new SymbolInfo("car.circle", "local_police"));
			mappings.Add("car.circle.fill", new SymbolInfo("car.circle.fill", "local_police"));
			mappings.Add("phone.circle", new SymbolInfo("phone.circle", "call"));
			mappings.Add("phone.circle.fill", new SymbolInfo("phone.circle.fill", "call"));
			mappings.Add("exclamationmark.triangle.fill", new SymbolInfo("exclamationmark.triangle.fill", "warning"));
			mappings.Add("exclamationmark.octagon", new SymbolInfo("exclamationmark.octagon", "dangerous"));
			mappings.Add("exclamationmark.octagon.fill", new SymbolInfo("exclamationmark.octagon.fill", "dangerous"));
			mappings.Add("shield.checkered", new SymbolInfo("shield.checkered", "security"));

			// Chemistry & Laboratory
			mappings.Add("flask.fill", new SymbolInfo("flask.fill", "biotech"));
			mappings.Add("testtube.2.fill", new SymbolInfo("testtube.2.fill", "science"));
			mappings.Add("atom.fill", new SymbolInfo("atom.fill", "science"));
			mappings.Add("microscope.fill", new SymbolInfo("microscope.fill", "biotech"));
			mappings.Add("drop.circle", new SymbolInfo("drop.circle", "water_drop"));
			mappings.Add("drop.circle.fill", new SymbolInfo("drop.circle.fill", "water_drop"));

			mappings.Add("snowflake.circle", new SymbolInfo("snowflake.circle", "ac_unit"));
			mappings.Add("snowflake.circle.fill", new SymbolInfo("snowflake.circle.fill", "ac_unit"));
			mappings.Add("thermometer.high", new SymbolInfo("thermometer.high", "device_thermostat"));
			mappings.Add("thermometer.low", new SymbolInfo("thermometer.low", "device_thermostat"));
			mappings.Add("scale.3d.fill", new SymbolInfo("scale.3d.fill", "scale"));

			// Mathematics & Engineering
			mappings.Add("plus.forwardslash.minus", new SymbolInfo("plus.forwardslash.minus", "calculate"));
			mappings.Add("multiply.circle", new SymbolInfo("multiply.circle", "calculate"));
			mappings.Add("multiply.circle.fill", new SymbolInfo("multiply.circle.fill", "calculate"));
			mappings.Add("divide.circle", new SymbolInfo("divide.circle", "calculate"));
			mappings.Add("divide.circle.fill", new SymbolInfo("divide.circle.fill", "calculate"));
			mappings.Add("equal.circle", new SymbolInfo("equal.circle", "calculate"));
			mappings.Add("equal.circle.fill", new SymbolInfo("equal.circle.fill", "calculate"));
			mappings.Add("triangle.inset.filled", new SymbolInfo("triangle.inset.filled", "change_history"));
			mappings.Add("square.inset.filled", new SymbolInfo("square.inset.filled", "square"));

			mappings.Add("ruler.trianglebadge.exclamationmark", new SymbolInfo("ruler.trianglebadge.exclamationmark", "straighten"));
			mappings.Add("level.fill", new SymbolInfo("level.fill", "straighten"));

			// Textiles & Fashion
			mappings.Add("tshirt", new SymbolInfo("tshirt", "checkroom"));
			mappings.Add("tshirt.fill", new SymbolInfo("tshirt.fill", "checkroom"));
			mappings.Add("eyeglasses", new SymbolInfo("eyeglasses", "visibility"));
			mappings.Add("sunglasses", new SymbolInfo("sunglasses", "visibility"));
			mappings.Add("shoe", new SymbolInfo("shoe", "directions_walk"));
			mappings.Add("shoe.fill", new SymbolInfo("shoe.fill", "directions_walk"));
			mappings.Add("shoe.2", new SymbolInfo("shoe.2", "directions_run"));
			mappings.Add("shoe.2.fill", new SymbolInfo("shoe.2.fill", "directions_run"));
			mappings.Add("handbag", new SymbolInfo("handbag", "shopping_bag"));
			mappings.Add("handbag.fill", new SymbolInfo("handbag.fill", "shopping_bag"));
			mappings.Add("case", new SymbolInfo("case", "work_outline"));
			mappings.Add("case.fill", new SymbolInfo("case.fill", "work"));

			// Energy & Environment
			mappings.Add("bolt.horizontal", new SymbolInfo("bolt.horizontal", "flash_on"));
			mappings.Add("bolt.horizontal.fill", new SymbolInfo("bolt.horizontal.fill", "flash_on"));
			mappings.Add("wind.circle", new SymbolInfo("wind.circle", "air"));
			mappings.Add("wind.circle.fill", new SymbolInfo("wind.circle.fill", "air"));
			mappings.Add("leaf.circle.fill", new SymbolInfo("leaf.circle.fill", "eco"));
			mappings.Add("sun.max.trianglebadge.exclamationmark", new SymbolInfo("sun.max.trianglebadge.exclamationmark", "wb_sunny"));
			mappings.Add("lightbulb.fill", new SymbolInfo("lightbulb.fill", "lightbulb"));
			mappings.Add("lightbulb.circle", new SymbolInfo("lightbulb.circle", "lightbulb"));
			mappings.Add("lightbulb.circle.fill", new SymbolInfo("lightbulb.circle.fill", "lightbulb"));
			mappings.Add("battery.25.bolt", new SymbolInfo("battery.25.bolt", "battery_charging_30", false));
			mappings.Add("battery.50.bolt", new SymbolInfo("battery.50.bolt", "battery_charging_50", false));
			mappings.Add("battery.75.bolt", new SymbolInfo("battery.75.bolt", "battery_charging_80", false));
			mappings.Add("plug.fill", new SymbolInfo("plug.fill", "power"));
			mappings.Add("outlet", new SymbolInfo("outlet", "electrical_services"));

			return mappings;
		}
	}
}
