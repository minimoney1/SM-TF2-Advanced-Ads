#if defined ADVERT_TF2COLORS

#define EXT_ADVERT_VERSION "1.1.1-tf2"

#else

#define EXT_ADVERT_VERSION "1.1.1-nontf2"

#endif

public SharedPlugin:__pl_adv_adverts = 
{
	name = "adv_adverts",
#if defined ADVERT_TF2COLORS
	file = "adv_adverts_tf2.smx",
#else
	file = "adv_adverts_nontf2.smx",
#endif
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

/**
 * 
 * Shows an advertisement
 * 
 * @param advertId		The ID of the advertisement that needs to be shown. NULL_STRING if you want to show the next advertisement.
 * 
 * @return				True if the advert was shown, false otherwise.
 * 
 */

native ShowAdvert(const String:advertId[] = NULL_STRING);

/**
 * 
 * Adds an advertisement to the advertisements list
 * 
 * @param advertId		The ID of the advertisement (As a string, does not need to be numerical)
 * @param advertType	The string that contains the letters for the type of the advertisement
 * @param advertText	The unedited string (with tags) of the advertisement
 * @param advertFlags	The bitwise representation of the admin flags that a client should have to view the ad.
 * @param noFlags		The bitwise representations of the admin flags that a client should not have to view the ad.
 * 
 * @return				True if the advert was successfully created, false if there is already an advert with the same name.
 * 
 */

native AddAdvert(const String:advertId[], const String:advertType[], const String:advertText[], advertFlags = -1, noFlags = -1);

/**
 * 
 * Adds a color to the top colors trie.
 * 
 * @param colorName		The color name (Without braces), this is the name that you will use inside of the '{' and '}' tags in the config.
 * @param red			The red value.
 * @param green			The green value
 * @param blue			The blue value
 * @param alpha			The alpha value
 * @param replace		If a color with an equal name was found, should we replace it?
 * 
 * @return				True on success, false on failure
 * 
 */

native AddExtraTopColor(String:colorName[], red, green, blue, alpha, bool:replace = true);

/**
 * 
 * Checks if a client can view the advertisement
 * 
 * @param client		The client index to check against
 * @param flagBits		The flagBits to check if client has, -1 if none.
 * 
 * @note				This is of great use in the forward OnPreClientReplace
 * 
 * @return				True if client can view the advertisement, false otherwise.
 * 
 */
native bool:Client_CanViewAds(client, flagBits = -1, noFlagBits = -1);

#if defined ADVERT_TF2COLORS
/**
 * 
 * Adds a color to the extra chat colors trie.
 * 
 * @param colorName		The color name (Without braces), this is the name that you will use inside of the '{' and '}' tags in the config.
 * @param hex			The exadecimal representation of the color (0xRRGGBB)
 * 
 * @note				To use this native, you need to have #define ADVERT_TOPCOLORS before including this file.
 * 
 * @return				True if the color was added, false if a color with an equal name was found
 */
native AddExtraChatColor(String:colorName[], hex);
#endif


/**
 * 
 * Called before replacing the advert tags (The tags inside of '{' and '}' braces.
 * 
 * @param advertId		The id of the advertisement as specified in the config
 * @param advertType	The string containing the advertisement type(s) as specified in the config. (By-Ref)
 * @param advertText	The text string of the advertisement including all the tags inside of '{' and '}' braces. (By-Ref)
 * @param advertFlags	The flag bits that a client needs to have to view this advertisement. (By-Ref)
 * 
 * @note 				All information passed on in this forward can be modified and changed, as it is all by-ref.
 * @note				Anything returned other than Plugin_Continue in this forward will make the advert stop and not go through.
 * 
 * @return				Plugin_Continue to allow the advert go through. Anything else would stop the advert from showing.
 * 
 */
forward Action:OnAdvertPreReplace(const String:advertId[], String:advertType[], String:advertText[], &advertFlags);

/**
 * 
 * Called before replacing the {CLIENT_} tags in the advert.
 * 
 * @param client		The client id of the client that is going to be shown the advert to (If the client passes the admin flag check)
 * @param advertId		The id of the advertisement as specified in the config. 
 * @param advertType	The string containing the advertisement type(s) as specified in the config. 
 * @param advertText	The text string of the advertisement including all the {CLIENT_} tags. (By-Ref)
 * @param advertFlags	The flag bits that a client needs to have to view this advertisement. (By-Ref)
 * 
 * @note 				The only two values pass by reference that can be modified are advertText and advertFlags.
 * 
 * @return				True if client will view the advertisement. False otherwise.
 * 
 */

forward bool:OnAdvertPreClientReplace(client, const String:advertId[], const String:advertType, String:advertText, &advertFlags);

/**
 * 
 * Called after the advertisement has been shown.
 * 
 * @param advertId		The id of the advertisement as specified in the config.
 * @param advertType	The string containing the advertisement type(s) as specified in the config.
 * @param advertText	The text string of the advertisement with all tags replaced.
 * @param advertFlags	The flag bits that a client needed to have to view this advert.
 * 
 * @note				No information can be modified to be shown to the clients at this point, as this is called after the advertisment.
 * 
 * @noreturn
 * 
 */
forward OnPostAdvertisementShown(const String:advertId[], const String:advertType[], const String:advertText[], advertFlags);


public __pl_adv_adverts_SetNTVOptional()
{
	MarkNativeAsOptional("AddExtraTopColor");
#if defined ADVERT_TF2COLORS
	MarkNativeAsOptional("AddExtraChatColor");
#endif
	MarkNativeAsOptional("Client_CanViewAds");
}