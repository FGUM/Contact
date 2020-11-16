#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Contact" 
#
# Module to populate & update a contact dictionary.
# 

var TRUE  = 1;
var FALSE = 0;

ContactManager = {
    #! \brief ContactManager constructor.
    #! \param contactFactory: The constructor for the contact. It is expected to take a property-node and an observer as parameter.
    #! \param contactObserver: The observer of the contact.
    new: func(contactFactory, contactObserver){
        var me = {parents: [ContactManager]};
        
        me.contactFactory = contactFactory;
        me.contactsUpdateCallback = nil;
        
        me.contactObserver = contactObserver;
        
        me.contactsMtx = thread.newlock();
        me.contacts = {};
        
        return me;
    },
    
    #! \brief Set the dictionary of contacts of the manager.
    #! \param contactDictionary: The dictionary of contacts.
    setContacts: func(contactDictionary){
        thread.lock(me.contactsMtx);
        me.contacts = contactDictionary;
        thread.unlock(me.contactsMtx);
        
        me.contactsUpdated();
    },
    
    #! \brief Add a contact to the manager.
    #! \param property: The property of the contact to add.
    addContact: func(property){
        var aiPath = property.getPath();
        
        # Instantiate the contact before locking the mutex, to minimize critical path. 
        var newContact = me.contactFactory(property, me.contactObserver);
        
        thread.lock(me.contactsMtx);
        me.contacts[aiPath] = newContact;
        thread.unlock(me.contactsMtx);
        
        me.contactsUpdated();
    },
    
    #! \brief Remove a contact from the manager.
    #! \param property: The property of the contact to remove.
    removeContact: func(property){
        var aiPath = property.getPath();
        
        thread.lock(me.contactsMtx);
        delete(me.contacts, aiPath);
        thread.unlock(me.contactsMtx);
        
        me.contactsUpdated();
    },
    
    #! \brief Called when the dictionary of contacts has been updated.
    contactsUpdated: func(){
        if(me.contactsUpdateCallback != nil)
            me.contactsUpdateCallback();
    },
         
    #! \brief Reset all buffers.
    resetBuffers: func(){
        # Clear all the buffers so the next computations are done with fresh values.
        me.contactObserver.reset();
        foreach(var contactPath; keys(me.contacts))
            me.contacts[contactPath].reset();
    },
    
    #! \brief Set the function to call when the contact list is updated.
    #! \param callback: The function to call when the contact list is updated.
    setUpdateCallback: func(callback){
        me.contactsUpdateCallback = callback;
    }
};
