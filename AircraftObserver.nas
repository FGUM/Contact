#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Contact" 
#
# Module with buffered accessors to regroup the data that will be used to define an observer for the contacts.
# The buffered part helps avoid accessing the property tree & doing the computations multiple times.
# The private members (_member) are not meant to be accessed directly, use the public accessors instead.
#

var Vec  = FGUM_LA.Vector;
var Quat = FGUM_LA.Quaternion;
var Rot  = FGUM_LA.Rotation3;

var BufMap = FGUM_Contact_Buffered.Map;
var BufAcc = FGUM_Contact_Buffered.Accessor;

#An observer for an AI contact.
AircraftObserver = {
    #! \brief AircraftObserver default constructor.
    new: func(){
        var me = {parents: [AircraftObserver]};
        
        # Properties for the aircraft pos private accessor (_acPosGeoAcc).
    	me._altProp = props.globals.getNode("position/altitude-ft");
    	me._latProp = props.globals.getNode("position/latitude-deg");
    	me._lonProp = props.globals.getNode("position/longitude-deg");
    	
    	# Properties for the aircraft attitude private accessor (_acAttitudeAcc).
        me._rollProp    = props.globals.getNode("orientation/roll-deg");
        me._pitchProp   = props.globals.getNode("orientation/pitch-deg");
        me._headingProp = props.globals.getNode("orientation/heading-deg");
            	
        me._uBodyProp = props.globals.getNode("velocities/uBody-fps");
        me._vBodyProp = props.globals.getNode("velocities/vBody-fps");
        me._wBodyProp = props.globals.getNode("velocities/wBody-fps");
    	
        append(me.parents, BufMap.new(me.genExprMap()));
        
        return me;
    },
    
    #! \brief  Creates the expression map to be used for the constructor of the `Buffered.Map` parent.
    #! \return The buffered expression map.
    genExprMap: func(){
        return {
            "PosXYZ"      : BufAcc.new(func(){return me._posXYZAcc();}),
            "PosGeo"      : BufAcc.new(func(){return me._posGeoAcc();}),
            "GeoRef"      : BufAcc.new(func(){return me._geoRefAcc();}),
            "Attitude"    : BufAcc.new(func(){return me._attitudeAcc();}),
            "Orientation" : BufAcc.new(func(){return me._orientationAcc();}),
            "VelUVW"      : BufAcc.new(func(){return me._velUVWAcc();}),
            "VelXYZ"      : BufAcc.new(func(){return me._velXYZAcc();}),
        };
    },
    
    #! \brief   Private accessor to compute the aircraft coordinates in the XYZ geocentric referential.
    #! \details The linked public accessor is `getPosXYZ()`.
    #! \return  The aircraft coordinates in the XYZ geocentric referential (Vector)(meters).
    _posXYZAcc: func(){
        return Vec.new(me.getPosGeo().xyz());
    },
    
    #! \brief   Private accessor to read the aircraft coordinates in the geodetic referential.
    #! \details The linked public accessor is `getPosGeo()`.
    #! \return  The aircraft coordinates in the geodetic referential (GEO object).
    _posGeoAcc: func(){
        return geo.Coord.new().set_latlon(me._latProp.getValue(), 
                                          me._lonProp.getValue(), 
                                          me._altProp.getValue()*FT2M);
    },
    
    #! \brief   Private accessor to compute the neutral attitude orientation at the current position 
    #!          relative to the neutral attitude at the intersection between the equator and prime meridian.
    #! \details The linked public accessor is `getGeoRef()`.
    #! \return  The relative neutral attitude orientation (Quaterinon).
    _geoRefAcc: func(){
        var pos = me.getPosGeo();
        return        Quat.fromAxisAngle([0, 1, 0], pos.lat() * D2R)
            .quatMult(Quat.fromAxisAngle([1, 0, 0], pos.lon() * D2R));
    },
    
    #! \brief   Private accessor to read the attitude of the aircraft.
    #! \details The linked public accessor is `getAttitude()`.
    #! \return  The current attitude of the aircraft (Quaterinon).
    _attitudeAcc: func(){
        return Quat.fromEuler([me._rollProp.getValue()    * D2R,
                               me._pitchProp.getValue()   * D2R,
                               me._headingProp.getValue() * D2R]);
    },
    
    #! \brief   Private accessor to read the orientation of the aircraft 
    #!          (relative to the neutral attitude at the intersection between the equator and prime meridian).
    #! \details The linked public accessor is `getOrientation()`.
    #! \return  The current orientation of the aircraft (Quaterinon).
    _orientationAcc: func(){
        return        me.getGeoRef()
            .quatMult(me.getAttitude());
    },
    
    #! \brief   Private accessor to read the velocity of the aircraft in it's own UVW referential.
    #! \details The linked public accessor is `getVelUVW()`.
    #! \return  The current velocity of the aircraft (Vector)(meters/seconds).
    _velUVWAcc: func(){
        return Vec.new([
            me._uBodyProp.getValue(),
            me._vBodyProp.getValue(),
            me._wBodyProp.getValue(),
        ]).scalarMult(FT2M);
    },
    
    #! \brief   Private accessor to compute the velocity of the aircraft in the geocentric XYZ referential.
    #! \details The linked public accessor is `getVelXYZ()`.
    #! \return  The current velocity of the aircraft (Vector)(meters/seconds).    
    _velXYZAcc: func(){
        return Rot.new(me.getOrientation()).apply(me.getVelUVW());
    },
};