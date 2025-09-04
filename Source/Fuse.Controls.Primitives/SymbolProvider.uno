using Uno;
using Fuse;

namespace Fuse.Controls.Primitives
{
	public class PlatformSymbol
	{
		public string Name { get; private set; }
		public bool IsFilled { get; private set; }

		public PlatformSymbol(string name, bool isFilled)
		{
			Name = name;
			IsFilled = isFilled;
		}
	}

	public static class SymbolProvider
	{
		public static PlatformSymbol GetPlatformSymbol(string universalName, bool isFilled)
		{
			SymbolInfo symbolInfo;
			if (!SymbolMapping.All.TryGetValue(universalName, out symbolInfo))
			{
				Fuse.Diagnostics.UserWarning("Symbol '" + universalName + "' not found in mapping. Displaying fallback symbol.", null);
				symbolInfo = SymbolMapping.All["missing_symbol"];
			}

			bool shouldFill = isFilled && symbolInfo.HasFillVariant;

			if defined(iOS)
			{
				string name = shouldFill ? symbolInfo.IOSName + ".fill" : symbolInfo.IOSName;
				return new PlatformSymbol(name, shouldFill);
			}
			else if defined(Android)
			{
				return new PlatformSymbol(symbolInfo.AndroidName, shouldFill);
			}

			return new PlatformSymbol("", shouldFill); // Should not happen
		}
	}
}
