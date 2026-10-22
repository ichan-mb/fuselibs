using Uno;
using Uno.Text;
using Uno.Net.Http;

namespace Fuse
{
	internal static class PhoneUriHelper
	{
		/**
			Normalizes a phone number.

			Removes visual separators and converts keypad letters to digits,
			while preserving `+`, `*`, `#`, `,` and `;` so international
			prefixes, USSD codes and DTMF pauses survive.
		*/
		public static string NormalizeNumber(string phoneNumber)
		{
			if (string.IsNullOrEmpty(phoneNumber))
				return phoneNumber;

			var builder = new StringBuilder();

			for (int i = 0; i < phoneNumber.Length; i++)
			{
				char c = phoneNumber[i];

				if (c >= '0' && c <= '9')
				{
					builder.Append(c);
					continue;
				}

				if (c >= 'a' && c <= 'z')
					c = Char.ToUpper(c);

				switch (c)
				{
					case '+':
					case '*':
					case '#':
					case ',':
					case ';':
						builder.Append(c);
						break;
					case 'A':
					case 'B':
					case 'C':
						builder.Append('2');
						break;
					case 'D':
					case 'E':
					case 'F':
						builder.Append('3');
						break;
					case 'G':
					case 'H':
					case 'I':
						builder.Append('4');
						break;
					case 'J':
					case 'K':
					case 'L':
						builder.Append('5');
						break;
					case 'M':
					case 'N':
					case 'O':
						builder.Append('6');
						break;
					case 'P':
					case 'Q':
					case 'R':
					case 'S':
						builder.Append('7');
						break;
					case 'T':
					case 'U':
					case 'V':
						builder.Append('8');
						break;
					case 'W':
					case 'X':
					case 'Y':
					case 'Z':
						builder.Append('9');
						break;
				}
			}

			return builder.ToString();
		}

		public static string PhoneNumberToTelUri(string phoneNumber)
		{
			var builder = new StringBuilder();
			builder.Append("tel:");
			AppendDialable(builder, NormalizeNumber(phoneNumber));
			return builder.ToString();
		}

		/** Builds an Android `smsto:` URI for a message compose intent. */
		public static string PhoneNumbersToSmstoUri(string[] recipients)
		{
			var builder = new StringBuilder();
			builder.Append("smsto:");

			// Android decodes percent escapes in the scheme-specific part.
			AppendRecipients(builder, recipients, true);
			return builder.ToString();
		}

		/**
			Builds an iOS `sms:` URI with a body.

			iOS expects the body in `&body=`; Android uses `smsto:` with intent
			extras instead.
		*/
		public static string PhoneNumbersToIosSmsUri(string[] recipients, string body)
		{
			var builder = new StringBuilder();
			builder.Append("sms:");
			AppendRecipients(builder, recipients, false);

			if (!string.IsNullOrEmpty(body))
			{
				builder.Append("&body=");
				builder.Append(Uri.EscapeDataString(body));
			}

			return builder.ToString();
		}

		/**
			Builds an iOS FaceTime URI.

			Accepts a phone number or an Apple ID email address.
		*/
		public static string PhoneNumberToFaceTimeUri(string phoneNumber, bool audioOnly)
		{
			var builder = new StringBuilder();
			builder.Append(audioOnly ? "facetime-audio:" : "facetime:");

			if (!string.IsNullOrEmpty(phoneNumber) && phoneNumber.IndexOf('@') >= 0)
				builder.Append(Uri.EscapeDataString(phoneNumber.Trim()));
			else
				AppendDialable(builder, NormalizeNumber(phoneNumber));

			return builder.ToString();
		}

		static void AppendRecipients(StringBuilder builder, string[] recipients, bool percentEncode)
		{
			if (recipients == null)
				return;

			for (int i = 0; i < recipients.Length; i++)
			{
				if (i > 0)
					builder.Append(",");

				var number = NormalizeNumber(recipients[i]);
				if (percentEncode)
					builder.Append(Uri.EscapeDataString(number));
				else
					AppendDialable(builder, number);
			}
		}

		static void AppendDialable(StringBuilder builder, string number)
		{
			if (string.IsNullOrEmpty(number))
				return;

			for (int i = 0; i < number.Length; i++)
			{
				char c = number[i];

				// '#' starts a fragment in a URL, so it must be percent-encoded.
				if (c == '#')
				{
					builder.Append("%23");
					continue;
				}

				if (c == '+' || c == '*' || c == ',' || c == ';' || (c >= '0' && c <= '9'))
					builder.Append(c);
			}
		}
	}
}
