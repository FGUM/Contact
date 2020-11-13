#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Loader for the Contact module 
#

io.load_nasal(resolvepath("FGUM/Contact/Buffered.nas"),         "FGUM_Contact_Buffered");
io.load_nasal(resolvepath("FGUM/Contact/AircraftObserver.nas"), "FGUM_Contact");
io.load_nasal(resolvepath("FGUM/Contact/Contact.nas"),          "FGUM_Contact");
io.load_nasal(resolvepath("FGUM/Contact/ContactManager.nas"),   "FGUM_Contact");
