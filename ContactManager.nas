#
# Authors: Axel Paccalin, Richard Harrison, 5H1N0B1.
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
    new: func(contactFactory){
        var me = {parents: [ContactManager]};
        
        me.contactFactory = contactFactory;
        me.aiProp = props.globals.getNode("ai/models");
        me.contactObserver = AircraftObserver.new();
        me.contacts = {};
        
        return me;
    },
    
    # TODO: See if we can update the contact dictionary through events instead of having to re-parse the tree each time!     
    #! \brief Populate and update the contact list, also reset all buffers.
    update: func(){
        # Read the property-tree and update the contact dictionary.
        me.readTree();
        
        # Clear all the buffers so the next computations are done with fresh values.
        me.contactObserver.reset();
        foreach(var contactPath; keys(me.contacts))
            me.contacts[contactPath].reset();
    },
    
    #! \brief Populate and update the contact list.
    readTree: func(){       
        # Dictionary (used as a data set) containing the path of all valid AI nodes available.
        var aiFound = {};
        
        foreach(var anAIProp; me.aiProp.getChildren()){  
            if(!me.testNodeValidity(anAIProp))
                continue;
            var aiPath = anAIProp.getPath();
            
            # Set the node as an available AI.
            aiFound[aiPath] = 1;
            
            # Check if the contact already exists. Otherwise, instantiate it in the contact dictionary.
            if(me.contacts[aiPath] == nil)
                me.contacts[aiPath] = me.contactFactory(anAIProp, me.contactObserver);
        }
        
        # If there is a contact in the the contact dictionary, that isn't in the aiFound set, this means that it doesn't exists anymore.
        foreach(var contactPath; keys(me.contacts))
            if(aiFound[contactPath] == nil)
                delete(me.contacts, contactPath);  # Delete the old contact.
    },
    
    #! \brief  Test whether an ai node can be parsed as a valid contact or not.
    #! \param  node: The ai node we want to test (Property-Tree node).
    #! \return Whether the node is a valid contact or not (Boolean).
    testNodeValidity: func(node){
        var propValid = node.getNode("valid");
        if(propValid == nil or propValid.getValue() != 1) # or anAIProp.getNode("impact") != nil # or size(anAIProp.pos.getChildren()) == 0)
            return FALSE;  # It is either an invalid entity or an impact report, ignore it.
                
        var posProp = node.getNode("position");
        if(posProp == nil or size(posProp.getChildren()) == 0)
            return FALSE;  # No positional data
        
        var xPos = posProp.getNode("global-x");
        var yPos = posProp.getNode("global-y");
        var zPos = posProp.getNode("global-z");
        if(xPos != nil and yPos != nil and zPos != nil)
            return TRUE;  # At least geocentric info available. 
            
        var lat = posProp.getNode("altitude-ft");
        var lon = posProp.getNode("latitude-deg");
        var alt = posProp.getNode("longitude-deg");
        if(lat != nil and lon != nil and alt != nil)
            return TRUE;  # Geodetic info available. 
            
        return FALSE;
    },
};
