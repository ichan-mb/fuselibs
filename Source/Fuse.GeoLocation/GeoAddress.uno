namespace Fuse.GeoLocation
{
	/**
		A geocoding result.

		The fields follow the naming used by the platform geocoders:
		`Name` is the feature/place name, `Street` is the thoroughfare,
		`City` is the locality, and `Region` is the administrative area.
	*/
	public class GeoAddress
	{
		readonly string _name;
		readonly string _street;
		readonly string _streetNumber;
		readonly string _city;
		readonly string _subLocality;
		readonly string _region;
		readonly string _subRegion;
		readonly string _country;
		readonly string _countryCode;
		readonly string _postalCode;
		readonly string _formattedAddress;
		readonly GeoCoordinates _coordinates;

		public string Name { get { return _name; } }
		public string Street { get { return _street; } }
		public string StreetNumber { get { return _streetNumber; } }
		public string City { get { return _city; } }
		public string SubLocality { get { return _subLocality; } }
		public string Region { get { return _region; } }
		public string SubRegion { get { return _subRegion; } }
		public string Country { get { return _country; } }
		public string CountryCode { get { return _countryCode; } }
		public string PostalCode { get { return _postalCode; } }
		public string FormattedAddress { get { return _formattedAddress; } }

		/**
			The coordinates of the address, when provided by the platform.
		*/
		public GeoCoordinates Coordinates { get { return _coordinates; } }

		public GeoAddress(
			string name,
			string street,
			string streetNumber,
			string city,
			string subLocality,
			string region,
			string subRegion,
			string country,
			string countryCode,
			string postalCode,
			string formattedAddress,
			GeoCoordinates coordinates)
		{
			_name = name != null ? name : "";
			_street = street != null ? street : "";
			_streetNumber = streetNumber != null ? streetNumber : "";
			_city = city != null ? city : "";
			_subLocality = subLocality != null ? subLocality : "";
			_region = region != null ? region : "";
			_subRegion = subRegion != null ? subRegion : "";
			_country = country != null ? country : "";
			_countryCode = countryCode != null ? countryCode : "";
			_postalCode = postalCode != null ? postalCode : "";
			_formattedAddress = formattedAddress != null ? formattedAddress : "";
			_coordinates = coordinates;
		}

		public override string ToString()
		{
			return _formattedAddress;
		}
	}
}
