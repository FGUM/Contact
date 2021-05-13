#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Contact" 
#
# Module with buffered accessors to regroup the data that is used to define an observed contact.
# The buffered part helps avoid accessing the property tree & doing the computations multiple times.
# The private members (_member) are not meant to be accessed directly, use the public accessors instead.
#

var Vec  = FGUM_LA.Vector;
var Quat = FGUM_LA.Quaternion;
var Rot  = FGUM_LA.Rotation3;

var BufMap = FGUM_Contact_Buffered.Map;
var BufAcc = FGUM_Contact_Buffered.Accessor;

var cordToAtt = Quat.fromAxisAngle([0, 1, 0], -90*D2R);

# The various types of contacts.
ContactTypes = {
    Air      : 0,
    Ground   : 1,
    Marine   : 2,
    Ordnance : 3, 
};

Contact = {
    #! \brief Contact constructor.
    #! \param prop: The ai property defining the contact.
    #! \param observer: The observer through which the contact is observed.
    new: func(prop, observer){
        var me = {parents: [Contact]};
        
        me._prop = prop;
        
        me.observer = observer;
        
        # Get the name of the model if available.
        var modelProp = prop.getNode("sim/model/path");
        me.model = modelProp != nil ? split(".", split("/", modelProp.getValue())[-1])[0] : "";
        
        # Get the callsign of the contact if available.
        var callsignProp = prop.getNode("callsign");
        me.callsign = callsignProp != nil ? callsignProp.getValue() : "";
        
        me._posProp = prop.getNode("position");
        
        # Properties for the pos private accessor (_posXYZAcc).
        me.geocentricAvailable = FALSE;
        me._xProp   = me._posProp.getNode("global-x");
        me._yProp   = me._posProp.getNode("global-y");
        me._zProp   = me._posProp.getNode("global-z");
        if(me._xProp != nil and me._yProp != nil and me._zProp != nil)
            me.geocentricAvailable = TRUE;
        
        # Properties for the pos private accessor (_posGeoAcc).
        me.geodeticAvailable = FALSE;
    	me._latProp = me._posProp.getNode("latitude-deg");
    	me._lonProp = me._posProp.getNode("longitude-deg");
    	me._altProp = me._posProp.getNode("altitude-ft");
    	if(me._latProp != nil and me._lonProp != nil and me._altProp != nil)
            me.geodeticAvailable = TRUE;
        
        # Ensure we have at least one coordinates system available;
        if(!(me.geocentricAvailable or me.geodeticAvailable))
            die("No positional data available");
    	
        # Properties for the attitude private accessor (_attitudeAcc).
        me._orientationProp = prop.getNode("orientation");
        me._rollProp        = me._orientationProp.getNode("roll-deg");
        me._pitchProp       = me._orientationProp.getNode("pitch-deg");
        me._headingProp     = me._orientationProp.getNode("true-heading-deg");
        
        # Properties for the velocity uvw private accessor (_velUVWAcc).
        me._speedProp = prop.getNode("velocities/true-airspeed-kt");
        me._uBodyProp = me._speedProp.getNode("uBody-fps");
        me._vBodyProp = me._speedProp.getNode("vBody-fps");
        me._wBodyProp = me._speedProp.getNode("wBody-fps");
        
        # Properties for the type private accessor (_typeAcc).
        me._missileProp  = prop.getNode("missile");
        me._munitionProp = prop.getNode("munition");
        
        # Extend `Buffered.map` with all the accessors.
        append(me.parents, BufMap.new(me.genExprMap()));
        
        return me;
    },
    
    #! \brief  Creates the expression map to be used for the constructor of the `Buffered.Map` parent.
    #! \return The buffered expression map.
    genExprMap: func(){
        return {
            "Type"               : BufAcc.new(func(){return me._typeAcc();}),
            "PosXYZ"             : BufAcc.new(func(){return me._posXYZAcc();}),
            "PosGeo"             : BufAcc.new(func(){return me._posGeoAcc();}),
            "GeoRef"             : BufAcc.new(func(){return me._geoRefAcc();}),
            "Attitude"           : BufAcc.new(func(){return me._attitudeAcc();}),
            "Orientation"        : BufAcc.new(func(){return me._orientationAcc();}),
            "VelUVW"             : BufAcc.new(func(){return me._velUVWAcc();}),
            "VelXYZ"             : BufAcc.new(func(){return me._velXYZAcc();}),
            "DPos"               : BufAcc.new(func(){return me._dPosAcc();}),
            "Range"              : BufAcc.new(func(){return me._rangeAcc();}),
            "ObserverRelativePos": BufAcc.new(func(){return me._obsRelativePosAcc();}),
            "ObserverRelativeDev": BufAcc.new(func(){return me._obsRelativeDevAcc();}),
            "ContactRelativePos" : BufAcc.new(func(){return me._contactRelativePosAcc();}),
            "ContactRelativeDev" : BufAcc.new(func(){return me._contactRelativeDevAcc();}),
            "ClosureSpeed"       : BufAcc.new(func(){return me._closureSpeedAcc();}),
            "GroundClearance"    : BufAcc.new(func(){return me._gndClearanceAcc();}),
            "RayTerrainHit"      : BufAcc.new(func(){return me._rayTerrainHitAcc();}),
        };
    },
    
    #! \brief  Equality operator between two contacts.
    #! \param  other: The other contact to compare to.
    #! \return A boolean flag representing whether or not the contacts are the same (bool).
    equals: func(other){
        return me._prop.getPath() == other._prop.getPath();
    },
    
    #! \brief   Private accessor to compute the type of the contact.
    #! \details The linked public accessor is `getType()`.
    #! \return  The type of the contact (ContactTypes).
    _typeAcc: func(){ 
        var pos = me.getPosGeo();
        var alt = pos.alt();
        
        # Check if it's a missile.
        if(me._missileProp != nil and me._missileProp.getValue())
            return ContactTypes.Ordnance;
            
        # Check if it's a bullet.
        if(me._munitionProp != nil and me._munitionProp.getValue())
            return ContactTypes.Ordnance;

        # Cheap air contact test.
        if(alt > 8900) # Higher than everest, this is an air contact.
            return ContactTypes.Air;
        
        # Expensive test due to ground clearance and terrain type.
        if(me.getGroundClearance() < 10){  # Less than 10m above surface.
            var geoInfo = geodinfo(pos.lat(), pos.lon());
            if (geoInfo != nil and geoInfo[1] != nil) {
                if(geoInfo[1].solid == 1)
                    return ContactTypes.Ground;
                else
                    return ContactTypes.Marine;
            } else {
                # If we can't get the geoinfo it is because the terrain didn't load. So doing a default altitude check to choose.
                if(alt > 10)  # More than 10m ASL with less than 10m AGL means ground target.
                    return ContactTypes.Ground;
                else          # Less than 10m ASL probably means marine target.
                    return ContactTypes.Marine;
            }
        }
        
        
        return ContactTypes.Air;
    },
    
    #! \brief   Private accessor to read the contact coordinates in the XYZ geocentric referential.
    #! \details The linked public accessor is `getPosXYZ()`.
    #! \return  The contact coordinates in the XYZ geocentric referential (Vector)(meters).
    _posXYZAcc: func(){
        if(me.geocentricAvailable)
            return Vec.new([me._xProp.getValue(),
                            me._yProp.getValue(),
                            me._zProp.getValue()]);
        else
            return Vec.new(me.getPosGeo().xyz());
    },
    
    #! \brief   Private accessor to compute the contact coordinates in the geodetic referential.
    #! \details The linked public accessor is `getPosGeo()`.
    #! \return  The contact coordinates in the geodetic referential (GEO object).
    _posGeoAcc: func(){
        if(me.geodeticAvailable)
            return geo.Coord.new().set_latlon(me._latProp.getValue(), 
                                              me._lonProp.getValue(), 
                                              me._altProp.getValue() * FT2M);
        else {
            var pos = me.getPosXYZ().data;
            return geo.Coord.new().set_xyz(pos[0], pos[1], pos[2]);
        }
    },
    
    #! \brief   Private accessor to compute the neutral attitude orientation at the current position 
    #!          relative to the neutral attitude at the intersection between the equator and prime meridian.
    #! \details The linked public accessor is `getGeoRef()`.
    #! \return  The relative neutral attitude orientation (Quaterinon).
    _geoRefAcc: func(){
        var pos = me.getPosGeo();
        return        cordToAtt
            .quatMult(Quat.fromAxisAngle([1, 0, 0], pos.lon() * D2R))
            .quatMult(Quat.fromAxisAngle([0, 1, 0], pos.lat() * D2R));
    },
    
    #! \brief   Private accessor to read the attitude of the contact.
    #! \details The linked public accessor is `getAttitude()`.
    #! \return  The current attitude of the contact (Quaterinon).
    _attitudeAcc: func(){
        return Quat.fromEuler([me._rollProp.getValue()    * D2R,
                               me._pitchProp.getValue()   * D2R,
                               me._headingProp.getValue() * D2R]);
    },
    
    #! \brief   Private accessor to read the orientation of the contact 
    #!          (relative to the neutral attitude at the intersection between the equator and prime meridian).
    #! \details The linked public accessor is `getOrientation()`.
    #! \return  The current orientation of the contact (Quaterinon).
    _orientationAcc: func(){
        return        me.getGeoRef()
            .quatMult(me.getAttitude());
    },
    
    #! \brief   Private accessor to read the velocity of the contact in it's own UVW referential.
    #! \details The linked public accessor is `getVelUVW()`.
    #! \return  The current velocity of the contact (Vector)(meters/seconds).
    _velUVWAcc: func(){
        return Vec.new([
            me._uBodyProp != nil ? me._uBodyProp.getValue() 
                                 : (me._speedProp != nil ? me._speedProp.getValue() * KT2FPS
                                                         : 0),
            me._vBodyProp != nil ? me._vBodyProp.getValue()
                                 : 0,
            me._wBodyProp != nil ? me._wBodyProp.getValue()
                                 : 0,
        ]).scalarMult(FT2M);
    },
    
    #! \brief   Private accessor to compute the velocity of the contact in the geocentric XYZ referential.
    #! \details The linked public accessor is `getVelXYZ()`.
    #! \return  The current velocity of the contact (Vector)(meters/seconds).    
    _velXYZAcc: func(){
        return Rot.new(me.getOrientation()).apply(me.getVelUVW());
    },
    
    #! \brief   Private accessor to compute the position differential from the observer to the contact.
    #! \details The linked public accessor is `getDPos()`.
    #! \return  The position differential from the observer to the contact (Vector)(meters).   
    _dPosAcc: func(){
        return me.getPosXYZ().vecSub(me.observer.getPosXYZ());
    },
    
    #! \brief   Private accessor to compute the distance separating the observer from the contact.
    #! \details The linked public accessor is `getRange()`.
    #! \return  The distance separating the observer from the contact (Scalar)(meters).
    _rangeAcc: func(){
        return me.getDPos().magnitude();
    },
    
    #! \brief   Private accessor to compute the position of the contact in the observer referential.
    #! \details The linked public accessor is `getObserverRelativePos()`.
    #! \return  The position of the contact in the observer referential (Vector)(meters).
    _obsRelativePosAcc: func(){
        # TODO: Debug, something wrong in there.
        return Vec.new(Rot.new(me.observer.getOrientation().conjugate())
                          .apply(me.getDPos().data));
    },
    
    #! \brief   Private accessor to compute the deviation of the contact in the observer referential.
    #! \details The linked public accessor is `getObserverRelativeDev()`.
    #! \return  The deviation of the contact in the observer referential (Quaternion).
    _obsRelativeDevAcc: func(){
        # TODO: Debug, something wrong when doing Quat.fromDirection(me.getObserverRelativePos());. But with the following code, it is ok.
        return me.observer.getOrientation().conjugate()
                          .quatMult(Quat.fromDirection(me.getDPos().data));
    },
    
    #! \brief   Private accessor to compute the position of the observer in the contact referential.
    #! \details The linked public accessor is `getContactRelativePos()`.
    #! \return  The position of the observer in the contact referential (Vector)(meters).
    _contactRelativePosAcc: func(){
        # TODO: Debug, something wrong in there (or in the obs equivalent).
        return Vec.new(Rot.new(me.getOrientation().conjugate())
                          .apply(me.getDPos().neg().data));
    },
    
    #! \brief   Private accessor to compute the deviation of the observer in the contact referential.
    #! \details The linked public accessor is `getContactRelativeDev()`.
    #! \return  The deviation of the observer in the contact referential (Quaternion).
    _contactRelativeDevAcc: func(){
        # TODO: Debug, something wrong when doing Quat.fromDirection(me.getContactRelativePos().data);. But with the following code, it is ok.
        return me.getOrientation().conjugate()
                 .quatMult(Quat.fromDirection(me.getDPos().neg().data));
        return Quat.fromDirection(me.getContactRelativePos().data);
    },
    
    #! \brief   Private accessor to compute the speed at which the contact and target are closing.
    #! \details The linked public accessor is `getClosureSpeed()`.
    #! \return  The speed at which the contact and target are closing (Scalar).
    _closureSpeedAcc: func(){
        # Copy the vectors so normalizing them has no side effects.
        var crp = FGUM_LA.Vector.new(me.getContactRelativePos().data).normalize();
        var orp = FGUM_LA.Vector.new(me.getObserverRelativePos().data).normalize();
        
        # The speed of the contact projected on the normalized observer position relative to the contact.
        # Plus
        # The speed of the observer projected on the normalized contact position relative to the observer.
        return me.getVelUVW()
                 .orthogonalProjection(crp)
             + me.observer.getVelUVW()
                 .orthogonalProjection(orp);
    },
    
    #! \brief   Private accessor to compute the contact altitude AGL.
    #! \details The linked public accessor is `getGroundClearance()`.
    #! \return  The contact altitude AGL (Scalar)(meters).
    _gndClearanceAcc: func(){
        var pos = me.getPosGeo();
        var gndAlt = geo.elevation(pos.lat(), pos.lon());
        if(gndAlt == nil)
            gndAlt = 0;
            
        return gndAlt - pos.alt();
    },
    
    #! \brief   Private accessor to compute the first collision between the ground and a ray emanating from the observer and going through the contact.
    #! \details The linked public accessor is `getRayTerrainHit()`.
    #! \return  The collision point or -1 is no collision (Vector or -1)(meters).
    _rayTerrainHitAcc: func(){
        # Compute a ray starting at the observer position and going towards the contact.
        var obsPos = me.observer.getPosXYZ();
        var dPos = me.getDPos();
        
        var obsXYZ = {"x": obsPos.data[0],                     
                      "y": obsPos.data[1],           
                      "z": obsPos.data[2]};
        
        var dyXYZ = {"x": dPos.data[0],                     
                     "y": dPos.data[1],           
                     "z": dPos.data[2]};
        
        # And intersect this ray with the ground.        
        var hit = get_cart_ground_intersection(obsXYZ, dyXYZ);
        
        # No intersection
        if(hit == nil)
            return -1; # Do not return nil, or it will mess up with the buffered accessor.
        
        # An intersection happened, convert it to an XYZ vector.
        var coord = geo.Coord.new();
        coord.set_latlon(hit.lat, hit.lon, hit.elevation);
        
        return Vec.new(coord.xyz());
    },
};