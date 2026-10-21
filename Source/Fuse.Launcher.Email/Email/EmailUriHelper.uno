using Uno;
using Uno.Collections;
using Uno.Text;
using Uno.Net.Http;

namespace Fuse
{
	/**
		Builds RFC 6068 `mailto:` URIs.

		The `to` path and the `cc`/`bcc` parameters keep the characters that are
		valid in an address (`@`, `,` and `.`), while everything else is
		percent-encoded. Subject and body are percent-encoded in full. Empty
		parameters are skipped so the URI never contains `?&`.
	*/
	internal static class EmailUriHelper
	{
		public static string BuildUri(EmailMessage message)
		{
			if (message == null)
				throw new ArgumentNullException(nameof(message));

			return BuildUri(message.To, message.CarbonCopy, message.BlindCarbonCopy,
				message.Subject, message.Body);
		}

		public static string BuildUri(string[] to, string[] cc, string[] bcc,
			string subject, string body)
		{
			var builder = new StringBuilder();
			builder.Append("mailto:");
			builder.Append(JoinRecipients(to));

			var hasQuery = false;
			AppendParameter(builder, ref hasQuery, "cc", JoinRecipients(cc), false);
			AppendParameter(builder, ref hasQuery, "bcc", JoinRecipients(bcc), false);
			AppendParameter(builder, ref hasQuery, "subject", subject, true);
			AppendParameter(builder, ref hasQuery, "body", body, true);

			return builder.ToString();
		}

		/**
			Splits comma- and semicolon-separated input and trims the resulting
			addresses. Empty entries are dropped.
		*/
		public static string[] Normalize(string[] recipients)
		{
			if (recipients == null)
				return new string[0];

			var result = new List<string>();
			foreach (var recipient in recipients)
			{
				if (recipient == null)
					continue;

				foreach (var commaPart in recipient.Split(','))
				{
					foreach (var part in commaPart.Split(';'))
					{
						var trimmed = part.Trim();
						if (!string.IsNullOrEmpty(trimmed))
							result.Add(trimmed);
					}
				}
			}

			return result.ToArray();
		}

		/** Normalizes a single comma- or semicolon-separated recipient string. */
		public static string[] FromString(string recipients)
		{
			if (string.IsNullOrEmpty(recipients))
				return new string[0];

			return Normalize(new string[] { recipients });
		}

		static string JoinRecipients(string[] recipients)
		{
			var normalized = Normalize(recipients);
			var builder = new StringBuilder();

			for (int i = 0; i < normalized.Length; i++)
			{
				if (i > 0)
					builder.Append(",");
				builder.Append(EncodeAddress(normalized[i]));
			}

			return builder.ToString();
		}

		static string EncodeAddress(string address)
		{
			if (string.IsNullOrEmpty(address))
				return "";

			// EscapeDataString encodes the address separators that are valid in
			// a mailto URI. Keep them readable for email clients.
			return Uri.EscapeDataString(address)
				.Replace("%40", "@")
				.Replace("%2C", ",")
				.Replace("%2E", ".");
		}

		static void AppendParameter(StringBuilder builder, ref bool hasQuery,
			string name, string value, bool encode)
		{
			if (string.IsNullOrEmpty(value))
				return;

			builder.Append(hasQuery ? "&" : "?");
			builder.Append(name);
			builder.Append("=");
			builder.Append(encode ? Uri.EscapeDataString(value) : value);
			hasQuery = true;
		}
	}
}
