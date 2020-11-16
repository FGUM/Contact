#
# Authors: Axel Paccalin, Richard Harrison, 5H1N0B1.
#
# Version 0.1
#
# Imported under "FGUM_Contact" 
#

var TRUE  = 1;
var FALSE = 0;

ContactProvider = {
    #! \brief ContactProvider constructor.
    #! \param contactFactory: The constructor for the contact. It is expected to take a property-node and an observer as parameter.
    new: func(contactFactory, contactsUpdateCallback=nil){
        var me = {parents: [ContactProvider, 
                            ContactManager.new(contactFactory,
                                               AircraftObserver.new())]};
        
        me.addedEventProp   = props.globals.getNode("ai/models/model-added");
        me.removedEventProp = props.globals.getNode("ai/models/model-removed");
        
        me.addModelListener    = nil;  #!< Listener for the contact addition event.
        me.removeModelListener = nil;  #!< Listener for the contact removal event.
        
        return me;
    },
    
    #! \brief Initialize the contact list, and set the listeners for further contact list updates.
    init: func(){
        me.addModelListener = setlistener("ai/models/model-added", func(){
            var contactProp = props.globals.getNode(me.addedEventProp.getValue());
            
            #TODO: We probably need to create an independent obj to handle the valid event, so multiple models don't mess with the readyListener. 
            # An added model might take some time to get valid, so we add a listener on it's "valid" property.
            var readyListener = setlistener(me.addedEventProp.getValue()~"/valid", func(){
                if(me.testNodeValidity(contactProp)){
                    me.addContact(contactProp);
                    removelistener(readyListener);
                }
            });
        });
        
        setlistener("ai/models/model-removed", func(){
            var contactProp = props.globals.getNode(me.removedEventProp.getValue());
            # TODO: Check whether or not it is possible that FG remove the node before the `model-removed` event. 
            if(contactProp == nil)
                die("Unexpected contact removal");
            
            me.removeContact(contactProp);
        });
        
        # Get the contacts that where there BEFORE the initialization.
        me.setContacts(me.readTree());
    },
    
    #! \brief  Generate a contact list by reading the tree.
    #! \detail Should only be run at initialization. The contact list is updated through events aver that.
    readTree: func(){       
        me.aiTree = props.globals.getNode("ai/models");
        var result = {};
        
        foreach(var anAIProp; me.aiTree.getChildren()){  
            if(!me.testNodeValidity(anAIProp))
                continue;
                
            var aiPath = anAIProp.getPath();
            
            result[aiPath] = me.contactFactory(anAIProp, me.contactObserver);
        }
        
        return result;
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
