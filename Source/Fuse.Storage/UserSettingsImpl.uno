using Uno;
using Uno.Collections;
using Uno.IO;

namespace Fuse.Storage
{
	interface IUserSettings
	{
		string GetStringValue(string key);

		double GetNumberValue(string key);

		bool GetBooleanValue(string key);

		void SetStringValue(string key, string value);

		void SetNumberValue(string key, double value);

		void SetBooleanValue(string key, bool value);

		void Remove(string key);

		void Clear();
	}
}