using Uno;
using Uno.UX;

using Fuse.Elements;
using Fuse.Controls;

namespace Fuse.Triggers
{
	/**
		Active while an element is positioned within the snapping area.
		```xml
			<ScrollView LayoutMode="PreserveVisual">
				<StackPanel>
					<Each Count="100" Reuse="Frame" >
						<Panel ux:Name="panel" Color="#AAA">
							<Text ux:Name="text" Value="Data-{= index() }"/>

							<WhileScrollSnapping>
								<Change panel.Color="Blue" />
								<Change text.Color="White" />
							</WhileScrollSnapping>
						</Panel>
					</Each>
				</StackPanel>

				<ScrollViewSnap SnapAlignment="Center" />
			</ScrollView>
		```

		@experimental
	*/
	public class WhileScrollSnapping : WhileTrigger, IPropertyListener
	{
		ScrollView _scrollable;
		ScrollViewSnap _scrollViewSnap;
		protected override void OnRooted()
		{
			base.OnRooted();
			_scrollable = Parent.FindByType<ScrollView>();
			if (_scrollable == null)
			{
				Fuse.Diagnostics.UserError( "Could not find a ScrollView control.", this );
				return;
			}

			_scrollable.AddPropertyListener(this);
			_scrollViewSnap = _scrollable.FirstChild<ScrollViewSnap>();

			if (_scrollViewSnap == null)
			{
				Fuse.Diagnostics.UserError( "Could not find a ScrollViewSnap Behavior.", this );
				return;
			}
		}

		protected override void OnUnrooted()
		{
			if (_scrollable != null)
			{
				_scrollable.RemovePropertyListener(this);
				_scrollable = null;
				_scrollViewSnap = null;
			}
			base.OnUnrooted();
		}

		static Selector _scrollPositionName = "ScrollPosition";

		void IPropertyListener.OnPropertyChanged(PropertyObject obj, Selector prop)
		{
			if (obj == _scrollable && prop == _scrollPositionName)
				SetActive(IsOn);
		}

		bool IsOn
		{
			get
			{
				if (_scrollable != null && _scrollViewSnap != null)
				{
					var snapAlign = _scrollViewSnap.SnapAlignment;
					var element = Parent as Element;
					var scrollPos = _scrollable.ToScalarPosition(_scrollable.ScrollPosition);
					switch (snapAlign)
					{
						case SnapAlign.Start:
							var from = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.GetChildSize * Within);
							var to = _scrollable.ToScalarPosition(element.ActualPosition + _scrollViewSnap.GetChildSize);
							return from <= scrollPos && to >= scrollPos;
						case SnapAlign.End:
							var from = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.CalculateOffset() - _scrollViewSnap.GetChildSize);
							var to = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.CalculateOffset() + _scrollViewSnap.GetChildSize * Within);
							return from <= scrollPos && to >= scrollPos;
						case SnapAlign.Center:
							var from = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.CalculateOffset() - _scrollViewSnap.GetChildSize * Within);
							var to = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.CalculateOffset() + _scrollViewSnap.GetChildSize * Within);
							return from <= scrollPos && to >= scrollPos;
					}
				}
				return false;
			}
		}

		float _within = 0.5f;
		public float Within
		{
			get { return _within; }
			set
			{
				_within = Math.Clamp(value, 0, 1);
				SetActive(IsOn);
			}
		}
	}

	public class ScrollSnapAnimation: Trigger, IPropertyListener
	{
		public bool Inverse { get; set; }

		ScrollView _scrollable;
		ScrollViewSnap _scrollViewSnap;

		double SnapScrollProgress
		{
			get
			{
				var snapAlign = _scrollViewSnap.SnapAlignment;
				var element = Parent as Element;
				var scrollPos = _scrollable.ToScalarPosition(_scrollable.ScrollPosition);
				bool isOn = false;
				var from = 0.0f;
				var to = 0.0f;
				switch (snapAlign)
				{
					case SnapAlign.Start:
						from = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.SnapInterval);
						to = _scrollable.ToScalarPosition(element.ActualPosition + _scrollViewSnap.SnapInterval);
						isOn = from <= scrollPos && to >= scrollPos;
						if (isOn)
						{
							from =  _scrollable.ToScalarPosition(element.ActualPosition);
						}
						break;
					case SnapAlign.End:
						from = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.CalculateOffset() - _scrollViewSnap.SnapInterval);
						to = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.CalculateOffset() + _scrollViewSnap.SnapInterval) ;
						isOn = from <= scrollPos && to >= scrollPos;
						if (isOn)
						{
							from = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.CalculateOffset());
						}
						break;
					case SnapAlign.Center:
						from = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.CalculateOffset() - _scrollViewSnap.SnapInterval);
						to = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.CalculateOffset() + _scrollViewSnap.SnapInterval);
						isOn = from <= scrollPos && to >= scrollPos;
						if (isOn)
						{
							from = _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.CalculateOffset());
							to =  _scrollable.ToScalarPosition(element.ActualPosition - _scrollViewSnap.CalculateOffset() + _scrollViewSnap.SnapInterval);
						}
						break;
				}
				if (isOn)
				{
					var p = 0.0f;
					var range = (to  -  from);
					if (scrollPos < from)
					{
						var idx = Math.Floor((scrollPos / range));
						p = Math.Abs((scrollPos / range) - idx);
					}
					else if ((to - scrollPos) == range)
						return 1;
					else if (Math.Mod(scrollPos, range) != 0)
					{
						var idx = 1 + Math.Floor((scrollPos / range));
						p = Math.Abs(idx - (scrollPos / range));
					}
					return Inverse ? 1-p : p;
				}
				return 0;
			}
		}

		protected override void OnRooted()
		{
			base.OnRooted();

			_scrollable = Parent.FindByType<ScrollView>();
			if (_scrollable == null)
			{
				Fuse.Diagnostics.UserError( "Could not find a ScrollView control.", this );
				return;
			}

			_scrollable.AddPropertyListener(this);
			_scrollViewSnap = _scrollable.FirstChild<ScrollViewSnap>();

			if (_scrollViewSnap == null)
			{
				Fuse.Diagnostics.UserError( "Could not find a ScrollViewSnap Behavior.", this );
				return;
			}
		}

		protected override void OnUnrooted()
		{
			if (_scrollable != null)
			{
				_scrollable.RemovePropertyListener(this);
				_scrollable = null;
				_scrollViewSnap = null;
			}
			base.OnUnrooted();
		}

		static Selector _scrollPositionName = "ScrollPosition";

		void IPropertyListener.OnPropertyChanged(PropertyObject obj, Selector prop)
		{
			if (obj == _scrollable && prop == _scrollPositionName)
				Seek(SnapScrollProgress);
		}
	}
}