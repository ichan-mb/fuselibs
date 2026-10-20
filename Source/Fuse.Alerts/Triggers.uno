using Uno;
using Uno.Collections;
using Uno.UX;

using Fuse.Elements;
using Fuse.Triggers.Actions;
using Fuse.Scripting;

namespace Fuse
{

	public class AlertArgs : EventArgs, IScriptEvent
	{
		string _buttonLabel;
		string _text;
		int _index = -1;

		public AlertArgs(string buttonLabel)
		{
			_buttonLabel = buttonLabel;
		}

		public AlertArgs(string buttonLabel, string text)
		{
			_buttonLabel = buttonLabel;
			_text = text;
		}

		public AlertArgs(string buttonLabel, string text, int index)
		{
			_buttonLabel = buttonLabel;
			_text = text;
			_index = index;
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			Serialize(s);
		}

		virtual void Serialize(IEventSerializer s)
		{
			s.AddString("buttonLabel", _buttonLabel);
			if (_text != null)
				s.AddString("text", _text);
			if (_index >= 0)
				s.AddInt("index", _index);
		}
	}

	public delegate void AlertHandler(object sender, AlertArgs args);

	/**
		This is trigger action for showing native alert dialog with a single button. Only available on iOS or Android

		## Example

		The following example shows how to use it:

		```javascript
		<JavaScript>
			module.exports = {
				handler: function(data) {
					if (data.buttonLabel == 'Yes'){
						console.log("yes button clicked")
					}
				}
			};
		</JavaScript>
		<Panel>
			<Button Text="Display Alert" Alignment="Center">
				<Clicked>
					<ShowAlert Message="Hello world!" OkLabelButton="Yes" Handler="{handler}"/>
				</Clicked>
			</Button>
		</Panel>
		```
		
	*/
	public class ShowAlert: TriggerAction
	{
		Node _target;

		string _title = "Alert";
		/**
			The title of the alert dialog
		*/
		public string Title
		{
			get
			{
				return _title;
			}
			set
			{
				_title = value;
			}
		}

		/**
			String message to show in the dialog
		*/
		public string Message
		{
			get; set;
		}

		string _okLabel;
		/**
			Ok label button on the alert dialog. Defaults to the platform-localized OK label.
		*/
		public string OkLabelButton
		{
			get
			{
				return _okLabel;
			}
			set
			{
				_okLabel = value;
			}
		}

		/**
			Optionally specifies a handler that will be called when this trigger is pulsed.
		*/
		public event AlertHandler Handler;

		extern(!MOBILE)
		protected override void Perform(Node n)
		{
			Fuse.Diagnostics.UserWarning("Alert dialog is not implemented for this platform", this);
		}

		extern(MOBILE)
		protected override void Perform(Node n)
		{
			_target = n;
			if (Message == null)
			{
				Fuse.Diagnostics.UserError("Message is null", this);
				return;
			}
			Fuse.Alerts.NativeAlerts.ShowAlert(Title, Message, Fuse.Alerts.NativeAlerts.ResolveLabel(OkLabelButton, false), OnOK, null, OnError);
		}

		void OnOK()
		{
			if (Handler != null)
			{
				var visual = _target.FindByType<Visual>();
				Handler(visual, new AlertArgs(Fuse.Alerts.NativeAlerts.ResolveLabel(OkLabelButton, false)));
			}
		}

		void OnError(string message)
		{
			Fuse.Diagnostics.UserWarning(message, this);
		}
	}

	/**
		This is a trigger action for showing an ok/cancel dialog. Only available on iOS or Android

		## Example

		The following example shows how to use it:

		```javascript
		<JavaScript>
			module.exports = {
				handler: function(data) {
					if (data.buttonLabel == 'Yes'){
						console.log("yes button clicked")
					} else if (data.buttonLabel == 'Cancel'){
						console.log("cancel button clicked")
					}
				}
			};
		</JavaScript>
		<Panel>
			<Button Text="Display Alert" Alignment="Center">
				<Clicked>
					<ShowConfirm Message="Are you sure want to logout?" OkLabelButton="Yes" CancelLabelButton="Cancel" Handler="{handler}"/>
				</Clicked>
			</Button>
		</Panel>
		```
		
	*/
	public class ShowConfirm: TriggerAction
	{
		Node _target;

		string _title = "Confirm";
		/**
			The title of the confirm dialog
		*/
		public string Title
		{
			get
			{
				return _title;
			}
			set
			{
				_title = value;
			}
		}

		/**
			String message to show in the dialog
		*/
		public string Message
		{
			get; set;
		}

		string _okLabel;
		/**
			Ok label button on the confirm dialog. Defaults to the platform-localized OK label.
		*/
		public string OkLabelButton
		{
			get
			{
				return _okLabel;
			}
			set
			{
				_okLabel = value;
			}
		}

		string _neutralLabel;
		/**
			Optional neutral button label. When set, a third button is shown.
		*/
		public string NeutralLabelButton
		{
			get
			{
				return _neutralLabel;
			}
			set
			{
				_neutralLabel = value;
			}
		}

		string _cancelLabel;
		/**
			Cancel label button on the confirm dialog. Defaults to the platform-localized Cancel label.
		*/
		public string CancelLabelButton
		{
			get
			{
				return _cancelLabel;
			}
			set
			{
				_cancelLabel = value;
			}
		}

		/**
			Whether the OK button uses destructive styling.
		*/
		public bool Destructive
		{
			get; set;
		}

		bool _cancelable = true;
		/**
			Whether Android allows dismissing with Back or an outside tap.
		*/
		public bool Cancelable
		{
			get
			{
				return _cancelable;
			}
			set
			{
				_cancelable = value;
			}
		}

		/**
			Optionally specifies a handler that will be called when this trigger is pulsed.
		*/
		public event AlertHandler Handler;

		extern(!MOBILE)
		protected override void Perform(Node n)
		{
			Fuse.Diagnostics.UserWarning("Confirm dialog is not implemented for this platform", this);
		}

		extern(MOBILE)
		protected override void Perform(Node n)
		{
			_target = n;
			if (Message == null)
			{
				Fuse.Diagnostics.UserError("Message is null", this);
				return;
			}
			Fuse.Alerts.NativeAlerts.ShowConfirmChoice(
				Title, Message,
				Fuse.Alerts.NativeAlerts.ResolveLabel(OkLabelButton, false),
				NeutralLabelButton,
				Fuse.Alerts.NativeAlerts.ResolveLabel(CancelLabelButton, true),
				Destructive, Cancelable,
				OnOK, OnNeutral, OnCancel, OnDismissed, OnError);
		}

		void OnOK()
		{
			Fire(Fuse.Alerts.NativeAlerts.ResolveLabel(OkLabelButton, false), 0);
		}

		void OnNeutral()
		{
			Fire(NeutralLabelButton, 1);
		}

		void OnCancel()
		{
			Fire(Fuse.Alerts.NativeAlerts.ResolveLabel(CancelLabelButton, true), 2);
		}

		void OnDismissed()
		{
			Fire(Fuse.Alerts.NativeAlerts.ResolveLabel(CancelLabelButton, true), -1);
		}

		void Fire(string label, int index)
		{
			if (Handler != null)
			{
				var visual = _target.FindByType<Visual>();
				Handler(visual, new AlertArgs(label, null, index));
			}
		}

		void OnError(string message)
		{
			Fuse.Diagnostics.UserWarning(message, this);
		}
	}

	/**
		This is a trigger action for showing a native text input dialog. Only available on iOS or Android.

		## Example

		```javascript
		<JavaScript>
			module.exports = {
				handler: function(data) {
					if (data.buttonLabel == 'OK'){
						console.log("entered: " + data.text)
					}
				}
			};
		</JavaScript>
		<Panel>
			<Button Text="Rename" Alignment="Center">
				<Clicked>
					<ShowPrompt Title="Rename" Message="Enter a new name" Placeholder="Name" OkLabelButton="Save" CancelLabelButton="Cancel" Handler="{handler}"/>
				</Clicked>
			</Button>
		</Panel>
		```
	*/
	public class ShowPrompt : TriggerAction
	{
		Node _target;

		string _title = "Prompt";
		/**
			The title of the prompt dialog
		*/
		public string Title
		{
			get
			{
				return _title;
			}
			set
			{
				_title = value;
			}
		}

		/**
			String message to show in the dialog
		*/
		public string Message
		{
			get; set;
		}

		/**
			Placeholder text for the input field
		*/
		public string Placeholder
		{
			get; set;
		}

		/**
			Initial value of the input field
		*/
		public string Value
		{
			get; set;
		}

		string _okLabel;
		/**
			Ok label button on the prompt dialog. Defaults to the platform-localized OK label.
		*/
		public string OkLabelButton
		{
			get
			{
				return _okLabel;
			}
			set
			{
				_okLabel = value;
			}
		}

		string _cancelLabel;
		/**
			Cancel label button on the prompt dialog. Defaults to the platform-localized Cancel label.
		*/
		public string CancelLabelButton
		{
			get
			{
				return _cancelLabel;
			}
			set
			{
				_cancelLabel = value;
			}
		}

		/**
			Whether the input should be obscured
		*/
		public bool Secure
		{
			get; set;
		}

		/**
			Whether the input must be non-empty before OK is enabled
		*/
		public bool Required
		{
			get; set;
		}

		int _minLength;
		/**
			Minimum input length before OK is enabled
		*/
		public int MinLength
		{
			get
			{
				return _minLength;
			}
			set
			{
				_minLength = value;
			}
		}

		string _keyboardType = "text";
		/**
			Keyboard type: "text", "email", "number", "phone" or "url"
		*/
		public string KeyboardType
		{
			get
			{
				return _keyboardType;
			}
			set
			{
				_keyboardType = value;
			}
		}

		/**
			Optionally specifies a handler that will be called when this trigger is pulsed.
		*/
		public event AlertHandler Handler;

		extern(!MOBILE)
		protected override void Perform(Node n)
		{
			Fuse.Diagnostics.UserWarning("Prompt dialog is not implemented for this platform", this);
		}

		extern(MOBILE)
		protected override void Perform(Node n)
		{
			_target = n;
			int minChars = MinLength;
			if (Required && minChars < 1)
				minChars = 1;

			Fuse.Alerts.NativeAlerts.ShowPrompt(Title, Message, Placeholder, Value, Fuse.Alerts.NativeAlerts.ResolveLabel(OkLabelButton, false), Fuse.Alerts.NativeAlerts.ResolveLabel(CancelLabelButton, true), Secure, KeyboardType, minChars, OnOK, OnCancel, OnError);
		}

		void OnOK(string text)
		{
			if (Handler != null)
			{
				var visual = _target.FindByType<Visual>();
				Handler(visual, new AlertArgs(Fuse.Alerts.NativeAlerts.ResolveLabel(OkLabelButton, false), text));
			}
		}

		void OnCancel()
		{
			if (Handler != null)
			{
				var visual = _target.FindByType<Visual>();
				Handler(visual, new AlertArgs(Fuse.Alerts.NativeAlerts.ResolveLabel(CancelLabelButton, true)));
			}
		}

		void OnError(string message)
		{
			Fuse.Diagnostics.UserWarning(message, this);
		}
	}

	/**
		An item in a @ShowActionSheet.
	*/
	public sealed class ActionSheetItem : PropertyObject
	{
		/**
			The label shown in the action sheet.
		*/
		public string Label { get; private set; }

		/**
			Whether this item is shown as destructive.
		*/
		public bool Destructive { get; set; }

		bool _enabled = true;
		/**
			Whether this item can be selected.
		*/
		public bool Enabled
		{
			get
			{
				return _enabled;
			}
			set
			{
				_enabled = value;
			}
		}

		[UXConstructor]
		public ActionSheetItem([UXParameter("Label")] string label)
		{
			Label = label;
		}
	}

	/**
		This is a trigger action for showing a native action sheet. Only available on iOS or Android.

		## Example

		```javascript
		<JavaScript>
			module.exports = {
				handler: function(data) {
					console.log("selected: " + data.buttonLabel + " (" + data.index + ")")
				}
			};
		</JavaScript>
		<Panel>
			<Button Text="Choose photo source" Alignment="Center">
				<Clicked>
					<ShowActionSheet Title="Photo source" CancelLabelButton="Cancel" Handler="{handler}">
						<ActionSheetItem Label="Camera" />
						<ActionSheetItem Label="Photo library" />
						<ActionSheetItem Label="Delete" Destructive="true" />
					</ShowActionSheet>
				</Clicked>
			</Button>
		</Panel>
		```
	*/
	public class ShowActionSheet : TriggerAction
	{
		Node _target;

		string _title = "Choose";
		/**
			The title of the action sheet
		*/
		public string Title
		{
			get
			{
				return _title;
			}
			set
			{
				_title = value;
			}
		}

		/**
			String message to show in the dialog
		*/
		public string Message
		{
			get; set;
		}

		string _cancelLabel;
		/**
			Cancel label button on the action sheet. Defaults to the platform-localized Cancel label.
		*/
		public string CancelLabelButton
		{
			get
			{
				return _cancelLabel;
			}
			set
			{
				_cancelLabel = value;
			}
		}

		List<ActionSheetItem> _items = new List<ActionSheetItem>();
		/**
			The items to show in the action sheet.
		*/
		[UXContent]
		public IList<ActionSheetItem> Items
		{
			get
			{
				return _items;
			}
		}

		/**
			Optionally specifies a handler that will be called when this trigger is pulsed.
		*/
		public event AlertHandler Handler;

		extern(!MOBILE)
		protected override void Perform(Node n)
		{
			Fuse.Diagnostics.UserWarning("Action sheet is not implemented for this platform", this);
		}

		extern(MOBILE)
		protected override void Perform(Node n)
		{
			_target = n;

			if (_items.Count == 0)
			{
				Fuse.Diagnostics.UserError("ShowActionSheet requires at least one ActionSheetItem", this);
				return;
			}

			var labels = new string[_items.Count];
			var destructive = new bool[_items.Count];
			var enabled = new bool[_items.Count];
			for (int i = 0; i < _items.Count; i++)
			{
				labels[i] = _items[i].Label != null ? _items[i].Label : "";
				destructive[i] = _items[i].Destructive;
				enabled[i] = _items[i].Enabled;
			}

			bool hasOrigin = false;
			float originX = 0;
			float originY = 0;
			var element = n as Element;
			if (element != null)
			{
				var position = element.ActualPosition + element.ActualSize * 0.5f;
				hasOrigin = true;
				originX = position.X;
				originY = position.Y;
			}

			Fuse.Alerts.NativeAlerts.ShowActionSheet(Title, Message, labels, destructive, enabled, Fuse.Alerts.NativeAlerts.ResolveLabel(CancelLabelButton, true), hasOrigin, originX, originY, OnSelect, OnCancel, OnError);
		}

		void OnSelect(int index)
		{
			if (Handler != null)
			{
				var visual = _target.FindByType<Visual>();
				var label = index >= 0 && index < _items.Count ? _items[index].Label : null;
				Handler(visual, new AlertArgs(label, null, index));
			}
		}

		void OnCancel()
		{
			if (Handler != null)
			{
				var visual = _target.FindByType<Visual>();
				Handler(visual, new AlertArgs(Fuse.Alerts.NativeAlerts.ResolveLabel(CancelLabelButton, true)));
			}
		}

		void OnError(string message)
		{
			Fuse.Diagnostics.UserWarning(message, this);
		}
	}
}