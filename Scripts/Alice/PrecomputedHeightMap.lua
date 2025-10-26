if Debug then Debug.beginFile "PrecomputedHeightMap" end ---@diagnostic disable: param-type-mismatch
do

      -- Ensure the library table exists and is visible to other files
        PrecomputedHeightMap = PrecomputedHeightMap or {}
        _G.PrecomputedHeightMap = PrecomputedHeightMap
    --[[
    ===============================================================================================================================================================
                                                                    Precomputed Height Map
                                                                        by Antares
    ===============================================================================================================================================================
   
    GetLocZ(x, y)                               Returns the same value as GetLocationZ(x, y).
    GetTerrainZ(x, y)                           Returns the exact height of the terrain geometry.
    GetUnitZ(whichUnit)                         Returns the same value as BlzGetUnitZ(whichUnit).
    GetUnitCoordinates(whichUnit)               Returns x, y, and z-coordinates of a unit.
    ===============================================================================================================================================================
    Computes the terrain height of your map on map initialization for later use. The function GetLocZ replaces the traditional GetLocZ, defined as:
    function GetLocZ(x, y)
        MoveLocation(moveableLoc, x, y)
        return GetLocationZ(moveableLoc)
    end
    The function provided in this library cannot cause desyncs and is approximately twice as fast. GetTerrainZ is a variation of GetLocZ that returns the exact height
    of the terrain geometry (around cliffs, it has to approximate).
    Note: PrecomputedHeightMap initializes OnitInit.final, because otherwise walkable doodads would not be registered.
    ===============================================================================================================================================================
    You have the option to save the height map to a file on map initialization. You can then reimport the data into the map to load the height map from that data.
    This will make the use of Z-coordinates completely safe, as all clients are guaranteed to use exactly the same data. It is recommended to do this once for the
    release version of your map.
    To do this, set the flag for WRITE_HEIGHT_MAP and launch your map. The terrain height map will be generated on map initialization and saved to a file in your
    Warcraft III\CustomMapData\ folder. Open that file in a text editor, then remove all occurances of
        call Preload( "
    " )
   
    with find and replace (including the quotation marks and tab space). Then, remove
    function PreloadFiles takes nothing returns nothing
        call PreloadStart()
    at the beginning of the file and
        call PreloadEnd( 0.0 )
    endfunction
    at the end of the file. Finally, remove all line breaks by removing \n and \r. The result should be something like
    HeightMapCode = "|pk44mM-b+b1-dr|krjdhWcy1aa1|eWcyaa"
    except much longer.
    Copy the entire string and paste it anywhere into the Lua root in your map, for example into the Config section of this library. Now, every time your map is
    launched, the height map will be read from the string instead of being generated, making it guaranteed to be synced.
    To check if the code has been generated correctly, launch your map one more time in single-player. The height map generated from the code will be checked against
    one generated in the traditional way.


    --=============================================================================================================================================================
                                                                          C O N F I G
    --=============================================================================================================================================================
    ]]
    local SUBFOLDER                         = "PrecomputedHeightMap"
    --Where to store data when exporting height map.
    local STORE_CLIFF_DATA                  = true
    --If set to false, GetTerrainZ will be less accurate around cliffs, but slightly faster.
    local STORE_WATER_DATA                  = true
    --Set to true if you have water cliffs and have STORE_CLIFF_DATA enabled.
    local WRITE_HEIGHT_MAP                  = false
    --Write height map to file?
    local VALIDATE_HEIGHT_MAP               = true
    --Check if height map read from string is accurate.
    local VISUALIZE_HEIGHT_MAP              = true
    --Create a special effect at each grid point to double-check if the height map is correct.
    HeightMapCode = "244In44BxIn63BxEa42Bx11E;6BxE;22Bx3|Kh34DN244In109DN+K42-K10|E;25L>E;2L>E;1DN1Bx|Kh34DN244In109DN+K43-K8|E;24L>3E;L>2E;1DNBx|Kh34DN244In109DN+K32|In1EaInEaInEa3-K7|H#E<-k4|H#E;17L>3E;2L>E;2DNBx|Kh35DN243In109DN+K30|In9Ea1-K6|HA+F-bn|Fk1H#3E;2H#E;2H#4E;2L>5E;6DNBx|Kh35DN243In109DN+K28|In12Ea-K5|Hv+O{-=jji+qe3|E;H#10E;L>6E;L>E;5Bx|Kh35DN243In59-f+f48|DN+K27|In14DN4E,HX-d|Jm-:Gd6+h-h3+.-.6|L>9E;3DNBx|Kh35DN243In58-ph+gq47|DN+K26|In15DN3EWHN+xfv-pgb3+bb-i+n-N+G1]-h|Hp+Z5|L>1-c+c6|E;3DNBx|Kh35DN243In57-htz+Hoe46|DN+K26|In15DN3E:HZ+p-n+efe4bqB|Hp+Z3G-G5|LQ+Ad-W+Y1-c+c4|E;L>E;DNBx|Kh35DN243In56-cipf+ooc46|DN+K17-b+b7|In15DN3E.HZ+p-ch+ib2b-b+b-bI+Gc4b-b3+v|L!+vjcN-ZZ+Xd6|DNBx|Kh35DN243In55-djkf+kmf47|DN+K15-cbb1+cbb4|In15DN3E*HZ+q1d-j+d1ck-jc3+bn-lbb4+gy|L(+qbm-kC+F-A+vb4|DN1Bx|Kh35DN243In54-cezB+Wff48|DN+K13-bfgi1+fgdec2|In16DN3FeHZ+rz-_b+K1-H|IJ-:+pc1-by+Lb-Bb+ehe-c+t|LE-r+Qjec-qp+Fcb2|E;1DN1Bx|Kh6-fqnb+jqk22|DN243In53-bfkd+ekf49|DN+K12-bevk3+mkhed1|In15Ea-K3|E>HN+Cdz-F+cdm-F+kf-chfw|F;-)d1+h|HR+j-jx|JhKx+!Rq-x+F-B+Fc4|E;1DNBx|Kh6-EEqKw+jFULgf18|DN243In50-b+b1b-kn+ogc50|DN+K12-dyj5+injec|In5-dm+dm5|Ea1-K3|FcH&+mcb-b+bE-zI+x-ck|FE-nrhfb1+eig;|G/IpJJ+<|LI+lq-B+Kcb5|DN1Bx|Kh6Jg-(?,p+vQ#^Upf17|DN243In49-b3+fx-M+id51|DN+K11-bkz7+joj|In5-fxsm+f$3|Ea2-K2+,|HJ+Be3c1-v+qb-f|Gg-*yd6+jK|GMH)JaKP+Ak(mdb5|E;DN1Bx|Kh6Iw-}|Gb-)l+I&;|IuJQ+yq17|DN243In48-b2e+bdd-c53|DN+K12-Ak8+p|In5-cyEFBB.|Ea5-K3|H#-e+e1-b+b1-bb+b-bo|FU-Wkb3+bb-b+bx<|HLI;J~+[!Fldb6|DN1Bx|Kh6H[-/|Fw-]t+J|F(+V|HLJo+OC17|DN243In46-b2bcho+N-nb53|DN+K11-eDd8+d|In4-bhDWUOPXZb4K3|E;H#1-bm+nb-b1cl|Gc-,xe3b+cY-Xc+p?|HWJcKd+;SAlbb5|DN2Bx|Kh6HYGWE>-_M+H|FG+U|HlI.+XS17|DN243In46-bbb2qe+vc54|DN+K11-cxl9|In5-cP|GS-:RJFtf4K3+?|H#2-p+D-nb1i|Gb-XDl4cP|Ft-&+E$|HZ+<|J!+;YJqedb3|E;DN3L>|Kh6H=G$FN-}Y+D|FN+)|HAIW+?X17|DN243In46+b-h+d-d+hC-E1+b54|DN+K11-bpu8|In7-p|F:-~xwpj1+b-c+c1-K4|FAH#1+n-F+rb1-l|F]-Wx5b+cO-F+I|Lx-c&+rFHo-sy+Yd3|DN3L>1|Kh6IkHk-M!X+o!<=[*O17|DN243In45+R-Ef+gc-t+d57|DN+K11-bjzb7|In8Ea+ib-fhbfggob5|H#2+Z-MG+t-e+e|Fj-nj6+bkJ|LC+Kh-jp+rc-P|ML-:+klb3|DN1L>2|Kh5-k|I:H[-Fwg+osOFU=A17|DN243In45+{-;g+b-cb58|DN+K12|InD[-s7|In8Ea1-cefjkg7|GGH#3+N-N2|E;9+bA|Ls+Tk-b1b2bQ+~-x4|E;DN2L>1|Kh6-V:Exic+mKEMTk17|DN243In44-H+H63|DN+K11|In3DN5In8Ea1-bdkph10|H#6E}-j5+bbb2T|K$L:+l1-z+T-.+T-b+b7|DN3L>|Kh6-pMIyn+eyzvEu18|DN243In42+{-{65|DN+K10|In18Ea2-cksg11|H#4-q<|Fd-q4+bdy-y+E-E+p?|K/+~l1n-n9|DN4Bx|Kh7-pwlg+hrjlk19|DN243In41-T+T66|DN+K10|In18Ea2-fpq12|E;H#2-oJ)|E;1+Q-Q2+cL1-XO+/-q+gK|LC+T5-y|JR2L>1E;DN4Bx|Kh35DN243In109DN+K9|In19Ea1-bgwh13|E;H#1-E[|F&-*K|FNEN+wbbcu-yF+Fc-b+jK|Lt+&1-Km|F{JO+g-d+d-d|E;2DN3Bx|Kh35DN243In109DN+K9|In19Ea1-bgxg13|E;1G#-v_:h+vE|EB+Ib1b1-bb+b1-b+bjs-B+Kgp|Jx+ph-bbg+g|E;1DN3Bx|Kh35DN243In109DN+K10|In17Ea3-gpp13|E;7+i-i5b+b1-by+zb-b+b-b+s|Jh+DjS-Sc1x|E;1DN3Bx|Kh35DN243In109DN+K11|In17Ea3-kug13+WQi9b-cF+Dc-j+iJ-Fc2+u|Jj-l+W-h+q-jcy|E>DN4Bx|Kh35DN243In109DN+K14|In14Ea3-cgoo12g+.Bmb3-n+p-bb+bs-.+xvjZ-yHc1+bm|G[Ia+ZE?n-OF|E*DN4Bx|Kh35DN243In109DN+K17|In10Ea5-bcceb+k2-K7+mYBj2-ne+V-Ae+bbQ-S1+dA-zdb1+bz/|HsIu+&-q+?-r|Fx-Ic|DN3Bx|Kh35DN243In109DN+K18|In8Ea14-K8+nSMd1bS-Lb+lgbb-hnf2b2+be[|G/Io+_Jd-w|Fl-yr|DN3Bx|Kh35DN243In109DN+K|In1Ea1InEa15In4Ea15-K9+t(y2i-i+K|Ji+m2-n|Fw-rmg4+bp|HlIU+*f1-x|Fl-y1|DN3Bx|Kh35DN243In109DNIn6Ea36-K8n+<N3|JR1-g+gbo-!+q-p|Fx-ss4+v|Jl+zfc1-x|Fl-y1|DN3Bx|Kh35DN243In118Ea35-K9+TVg1|JR3-bB+}|Jg+eA-l+s|E;+y3r|Jx-A+Tb1-w|Fp-Ac|DN3Bx|Kh35DN243In120Ea33-K9+L&h|JR6+h-H+A5-x2+g-j+Q-w+g1-o|GOE;2DN2Bx|Kh35DN243In122Ea31-K9+,J1|JR17+M-OD+Eb1-e+e|GzE;1DN2Bx|Kh35DN243In123Ea29-K10|E;1JR17-J+x-I+Rd4|Gz1E;DN2Bx|Kh35DN243In109DNIn13Ea28-K10|E;1JR18+h-hb+b5|Gz1E;DN1Bx|Kh35DN243In109DN+K|In13Ea27-K11|E;1JR5-be+bdb2N-N8+n-n2|Gz1E;DN1Bx|Kh35DN243In109DN+K2|In12Ea26-K12|E;JR-g+g2-chI+lCdb-n+}-Tn6+.-{h+n|Gz3DN1Bx|Kh35DN243In109DN+K3|In12Ea1+b-b15|InEa5-K13|FhJi+rg-gj|HR+oD[Te1-F+G6-[+[3|Gz2E;DN1Bx|Kh35DN243In109DN+K5|In9-r|FNEN-wod14|In3Ea2-K12+M)ws|I}Fx-m+*yHK|Jb+tnlT-Sc3+Tt-GG1|GE-f2|E;1DNBx|BxDN2+E32-E242|In109DN+K6|In7-e?|Go-}VDpc12|In5Ea1-K13|EN+whg-gf+eGj?rs|I?+Jb-b1+x3N-N2|Gz2E;1DN1Bx|BxDN2+E32-E242|In109DN+K5|In7-btQ]=(SAib11|In6Ea-K13+RZe2-dy+Cgfbg-d+z-s+bb1-z|JR4Gz1E;3DN1Bx|BxDN2+E32-E242|In109DN+K5|In7-dmFQX:#Ud11|In7Ea-K14+>xc-bAv+;-mbdC+;-)+ybbJ-Bk1|JRE;7DN1Bx|BxDN2+E32-E242|In109DN+K6|In7-frBGY|EU-U12|In7Ea-K14+i|EV+obkt-uibb1+c-cb+z-T+Xo-P9|DN2Bx|BxDN2+E32-E242|In109DN+K6|In8-fik+lm|Ea12In7Ea-K15+TXeb-en+v-f3cU1|F)Eb+:9|DN3Bx|BxDN2+E32-E242|In109DN+K|In15-b+b1|Ea14In6Ea-K15+d{wc-cnc+s3-bc+eZ-Zc+b8|DN3Bx|BxDN2+E32-E242|In109DNIn19Ea14F;Ht+/5|DN16+k$Bd-s+Bb-fb1+b1bb-bb8|DN4Bx|BxDN2+E32-E242|In131Ea11+bO|FUG)+*O5|DN17+RFg1B-cU+Mc-b12|DN4Bx|BxDN2+E32-E242|In109DNIn21Ea10+tU#{=On4|DN17-E+zNwrm-=|Fn-E+cc11|DN4Bx|BxDN2+E32-E242|In133Ea8+bA$**&Il3|DN21-v+tfsrvopbhc2-b+b-chC:5|Bx|BxDN2+E32-E242|In133Ea8+bj|FmGt+<Yw4|Ea-K23?+?-w+zuCAp-fg+b-mqDz6|Bx|BxDN2+E32-E242|In131Ea11+Pt|G{+,E5|Ea-K29+khcd-mk9|Bx|BxDN2+E32-E242|In130Ea11In10Ea-K44|Bx|BxDN2+E32-E242|In109DNIn19Ea6In15Ea-K44|Bx|BxDN2+E32-E242|In109DN+K|In17Ea5In17Ea-g19E24|Bx|BxDN2+E32-E242|In109DN+K1|In5Ea1In3Ea1In1Ea5In18D/20-E24|Bx|BxDN2+E32-E242|In109DN+K2|In3Ea3In1Ea10In17D/41-E4|Bx|BxDN2+E32-E242|In109DN+K23|In17D/41-E4|Bx|BxDN2+E32-E242|In109DN+K22|In18D/41-E4|Bx|BxDN2+E32-E242|In109DN+K23|In17D/43-E2|Bx|BxDN2+E32-E242|In109DN+K23|In17D/43-E2|Bx|BxDN2+E32-E242|In109DN+K23|In17D/43-E2|Bx|BxDN2+E32-E242|In109DN+K24|In16D/43-E2|Bx|BxDN2+E32-E242|In109DN+K25|In16D/42-E2|Bx|BxDN2+E32-E242|In109DN+K11-g14+g|In13D/43-E2|Bx|BxDN2+E36-E238|In109D/86-E2|Bx|BxDN2+E36-E238|In109D/86-E2|Bx|BxDN2+E36-E238|In109D/86-E2|Bx|BxD/39-E238|In109D/86-E2|Bx|BxD/39-E238|In109D/86-E2|Bx|D/40-E238|In109D/86-E2|Bx|D/40-E238|In70DN38+E86-E2|Bx|D/40-E238|In70DN38+E86-E2|Bx|D/39-E239|In70DN38+E86-E2|Bx|D/39-E349+E86-E2|Bx|D/39-E349+E86-E2|Bx|D/39-E349+E86-E2|Bx|D/39-E349+E86-E2|Bx|D/39-E349+E86-E2|Bx|D/39-E349+E86-E2|Bx|D/39-E349+E86-E2|Bx|D/40-E348+E86-E2|Bx|D/40-E348+E86-E2|Bx|D/40-E348+E86-E2|Bx|D/40-E348+E88-E|Bx|D/40-E348+E88-E|Bx|D/40-E348+E88-E|Bx|D/40-E348+E88-E|Bx|D/40-E348+E89|Bx|D/40-E348+E90|D/40-E348+E90|D/40-E348+E90|D/40-E348+E90|D/39-E349+E90|D/39-E349+E90|D/39-E349+E90|D/39-E349+E90|D/39-E349+E90|D/39-E349+E90|D/39-E349+E90|D/39-E349+E90|D/39-E349+E90|D/39-E349+E90|D/39-E349+E90|D/39-E349+E90|D/39-E349+E90|BxD/38-E349+E90|BxDN388+E90|BxDN388+E90|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN438+E40|BxDN436+E42|BxDN436+E27|S#D/1S#D/1S#D/7|BxDN434+E9|S#14D/1S#12D/4|BxDN434+E4|S#35D/3|BxDN434+E1|S#39D/2|BxDN428S#48D/1|BxDN428S#49D/|BxDN428S#50|BxDN428S#50|BxDN427S#51|BxDN427S#51|BxDN427S#51|BxDN427S#51|BxDN427S#51|BxDN427S#51|BxDN427S#51|BxDN427S#51|BxDN426S#52|BxDN426S#52|BxDN426S#52|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN425S#53|BxDN426S#52|BxDN426S#52|BxDN426S#52|BxDN426S#52|BxDN426S#52|BxDN426S#52|BxDN427S#51|BxDN427S#51|BxDN427S#51|BxDN430S#38DN8Bx|BxDN431S#37DN8Bx|BxDN432S#18DN26Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN236+G6-G234|Bx|BxDN233+G-G1+G10-G230|Bx|BxDN230+G17-G229|Bx|BxDN230+G18-G228|Bx|BxDN228+G21-G227|Bx|BxDN228+G21-G227|Bx|BxDN227+G22-G227|Bx|BxDN226+?-C23G226|Bx|BxDN225+?;|D}22-G227|Bx|BxDN225FmD}24-G226|Bx|BxDN225+G25-G226|Bx|BxDN224+?-C25G226|Bx|BxDN224FmD}25-G226|Bx|BxDN224+G26-G226|Bx|BxDN223+?,|D}26-G225|Bx|BxDN224FsD}26-G225|Bx|BxDN224FmD}26-G225|Bx|BxDN224FmD}25-G226|Bx|BxDN224Fm+g|D}24-G226|Bx|BxDN224+?,|D}23-G227|Bx|BxDN226+G22-G228|Bx|BxDN226FmD}21-G228|Bx|BxDN226+?/|D}19-Dd228|Bx|BxDN227Fm+g|D}17-Dd229|Bx|BxDN227+?,g|D}15-Dd230|Bx|BxDN229Fm+g|D}12-G233|Bx|BxDN229+?1,|D}8+I-,d234|Bx|BxDN232Fm+g1|D}FsD}Fs-,g?236|Bx|BxDN232+?-?3|FmDN239Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN478Bx|BxDN13I{DN2I{DN2I{DN5I{DN448Bx|BxDN6I{DNI{DNI{21DN3I{1DNI{DN1I{DN21I{DN2I{DNI{DN1I{DN402Bx|BxDN3I{42DN8I{DNI{DNI{DNI{16DN399Bx|BxDN2I{4-cb+cb39|DN1I{27DN397Bx|BxDN1I{3-djoJ+Lphc70|DN394Bx|BxDNI{3-dA{xb+tG(pc72|DN391Bx|BxI{4-u|HJ-ZA+cxQV?n73|DN390Bx|BxI{3-gT|G>-(ze+zU[:Ii74|DN388Bx|BxI{3-g|HS-/)Fh+tY:(?pd1b60-dfcb+bcfd3|DN388Bx|I{4-g|HWGW-?Pl+sX]ZJSmked58-hgfdb+bdfgh3|DN387Bx|BxI{3-dB|G#-_Qp+sKVODDxBkjhb44-b2+b5-b+b-kqok|Fn2IN+jhih2|DN387Bx|I{4-bq|Hx-[Vs+fACwxCAvqztf42-b8+b-bepzB|Fn5IH+pjn3|DN386Bx|I{4-bnC|Hp-Myk+cilrBzyvwBs40-b3b1b+b2-b1gzJO|FM-mfi4|IJ+rs3|DN386Bx|I{4-bks|HJ-ztpmf+bouyDuxDwg-c37b3bb1ccbbchrM=|F,-Eb+d-jfi2|Iw+xz3|DN386Bx|I{5-flj|HK-jotnh+fowEtsCNvMr-m+Fl-u|I{+H-lw27b3bbbdfiigiotI.?Ic+rc-kw2|Ij+Ftl3|DN385Bx|I{6-ffc_kyyob+ivytjvVUsec*J-P|JS-Jfj27b2bbbdhpvyrpU+t-xOZCh+Eq-qE2|Ia+Mwk3|DN385Bx|I{5+B-B1+g-oyPDuh+jqskcmx;CuwKi-I|Jv-A17+h-dcc7b2bbbdiqDOOCAviit+m-tp+mk-kw2|H>+Qwi3|DN385Bx|I{4+jEG-nLtmxHyk+dkl2ciw|JP+Pj-csQI15+jfvvh-(+o-w6b1bbbeisERYPBrleddb+s-rk+e-fi2|If+Pvd4|DN384Bx|I{4+otw-jyueipJqd+d4be-f|Kf-tJwj16+Nwoqd-wKBj4b1b1cejsESZTDqjeb4+b-mfbb1|HT+WLp5|DN384Bx|I{4+rtd-ijng+d-hj(l9|Je-j7+jf-fj7+YIuh-bxItyjb1b2bbdjsFT!RFshe7+d-d+cg|Hs+!RDd5|DN384Bx|I{4+wl-li+oimb-zy1|H/9I{5+jfdkb-oo6+dQLAi-fpGmDvc1b2bcfqDV(UHridb7+Idw=[UHk5|DN385Bx|I{4+Fp-pw+soG-cEP2|H/9I{3+jsb-b+b-bsj7+BIzp1-Asfyvh1b1b1dhyP[)Nukeb7+g;IONLGo7|DN384Bx|I{4+Nv-vN+jnIh-uv1nj|H/5+bi*1cimo1-jkdfj7+bkwwl-gBbclof1b1bbdmB!,!Hmfc8+kD|HX+FADk3w-w3|DN384Bx|I{4+Sv-vS2+oon1-ilif|H/2+bbhs(kflfe-osj11+bkqf-nn+de-egd1b1cbfpM?.Uujd8+cu|Ib+Ykef9|DN384Bx|I{4+Fp-pF2+jsji-ifdbk|Ie-b+cioNplie-dkmj13+bb-c+c-c+bb1-bb2ccdjwW})Dqfb8+eH|H/+)tb10|DN384Bx|I{4+jf-fj3+jfion-fqbii*+Silfed1-jibb3+jf-fj15+b2-dfjqH]_Qwjd9+eq#|IG+Hf10|DN384Bx|I{13+jGo-gBfdfl+bc1-b1+bb-bb5+of-ff+f-fj5+b2-b1+bccb-cgmvDV]WDmfb9+ckW|Ik+Zib9|DN384Bx|EiI{13+ry-fwo17+jnjf-iof+fd-dfj+id-ee1+beeb-fnyJVZUFqhc10+biK|H?+;ucb8|DN384Bx|I{15+jn1-nj16+jsOp-DK+kb-b+b-bs+ec-ff+cdef-clzLYZTIqie11+bet,|IA+Neb9|DN383Bx|I{16+owf-yr15+ow;d-RS+o-bk+kb-oe+d-ec+eedb-hxNW$UHvjdb11+bfx[|IA+Mfb8|DN384Bx|EiI{15+jOl-yK15+rP$-h)N+f-fj+jf-f1+d-cb+fd1-juJV!UIvlfb12+bjL|HV+#Beb8|DN384Bx|Ei1I{Ei+rysi|I{9+Fp-pF10+bfjeuGxc-CUw6+ng-bb+b-biuJWZTHvnfc13+bkN|HR+~Bh9|DN318Ju66|Ei8I{8+jf-fj9+bojknEq-dGBwj6+roc-dgjqKX[VIumgc14+bfy*|Iq+Vgb8|DN318Ju66|Ei8I{21+bpnmkf-bqEj8+orj-clC1h|HP-:&zlgd16+dp=|Ik+Yic9|DN317Ju66|Ei9I{21+piie-cvm9+jwl1-lhxcnU|G/-*Gld17+biQ|H&+~vc9|DN317Ju66|Ei10I{21+hh1-ig8+jnFy-kNn1pchE/|Gn-Opc18+fy#|IB+Ne9|DN317Ju66|Ei12I{21+b-b9+wPP1-tJDrfcetW|G]-.Dj18+fz=|IC+Me9|DN317Ju66|Ei16I{7EiI{19+F=F-twzCCm+i1-jA[|GP-!Ah17+hN|H}+(qd10|DN316Ju66|Ei17I{5Ei2I{18+wYG-kosLDn+keej-B^|GS-[Bdb14+bi!|Il+Zhb10|DN316Ju66|Ei19I{1Ei6I{16+jBBo-jBCso+ndmB-mY.Q$OEj13+ft!|IE+Jf11|DN316Ju66|Ei30I{15+jwnd-mtu+c-b1+it-dywfC&|Gr-!j11+cqX|Ig+Uqc11|DN316Ju66|Ei32I{13-i+sji-igon+jbb-be1+jdj-P|HQGD-)r10+dG|HKIL+Ceb10|DN317Ju66|Ei35I{9-Nl+GBi-efjlo+vd-bbf1g+k-lB:.>x9+lJ/|IL+Ed12|DN316Ju66|Ei37I{1EiI{1EiI{1GwHw+)Tf-g1+gfk-b+b1-bcfjhj1+h-T|GN-~p6+ber!|HZ+/wd11|DN317Ju66|Ei45+/|Gx+>$C-mb+jU3-b1ccehjh+H-c|H&Gc-Qe4+bfkz?|H~+)tc12|DN316Ju66|Ei44+dg|FH+,&Z-fe+oB:3-bbbbceg+st-M|Hd-=Ayn1+chktJ]}Vob11|DN317Ju66|Ei44+bgDPHWPwwG|I/4-bb1bbb+dm-g[vs:~we+lsCR&!Fjc11|DN317Ju66|Ei45+ckpgT[ZIIL{5-i+ec1-c+eh-f+j-sJ<VT+ezHSSIrfb12|DN316Ju66|Ei45+bb-dc+G]:TOP|I/4+d-b+v-y1bb+b-c+t-F+u-vK|Hm-m+rIKEsic12|DN317Ju66|Ei47+b-l+uS=!VTM#2ijjlW-DjGukxz+IO-g_v+izzqj1-b12|DN317Ju66|Ei48-d1+KY(!VRHCstg-dg+rC-dFFloo+jBf-sn+frmjb-hb12|DN317Ju66|Ei49-c+sP(&XSKBsDoqfGv-p(Dllid+mj-b+blkgc-hg13|DN317Ju66|Ei50+eGY$ZTKBuzwCyJ-dFQpimnh+emoiihe-hj13|DN318Ju66|Ei50+brQXZVMExvwFIC-fHyibjxun+uCpkf-cm15|DN317Ju66|Ei51+cGQWXULDQUuiqd-ootb+e-nXI+dKFte-di15|DN317Ju66|Ei52+hFOZ[$Q=$p-k+kAc-pF+bd1-KZx+nLye17|DN317Ju66|Ei53+iuT~|G^+*?$k-k+cIm-gNeb+j-nJOm+qyrc16|DN317Ju66|Ei29-bbb1b+cc18bo|FxGOH!I]+Aon-f+wk-jFlc+i-bpAxc+pvi15|DN318Ju66|BxEi26-cdgenmb+qnidb17K|F{HDIS+JBwfeb-yIj1+db-elxp+jzmc15|DN317Ju66|Ei26-diot6+fwod17<|G=IP+DwHid-lyF1+bb1-chuu+bxud15|DN317Ju66|Ei25-doql9+yrd16u|HRI.+gjJlg-ppF1+jf-ehhpsc+ssd14|DN318Ju66|BxEi6G=2Ei13-cpti11+Apd16|IF+N2wCM-yzN1+wn-ewlghb+gjb15|DN317Ju66|Ei4G=6Ei1+d-d9mso13+Gm17|I{2+jGP-dRK1+wy-nwti+dkcb16|DN317Ju66|Ei3G=8E_-Pnd7dpxd13+hJc16|I{3+rB1-Br1+jm-bpCn+ovb17|DN317Ju66|Ei2G=5-b+b-fF=:Ijc6dvu15+Lh17|I{9+c1-cH+bCw-s16|DN318Ju66|Ei1G=4-cgdfhyTSSub6eyq15+Glb17|I{8+cpo-Fb+yi-Dc16|DN317Ju66|Ei1G=3-fqljikuFNIs7gyo15+uy18|I{8+kDp-Qr+vl-zc15|DN318Ju66|EiG=3-gwwtplkoxExg5b+b-fzo15+Fn17|I{6+jf-f+nzf-Vx+nz-lib15|DN317Ju66|EiG=4-$JBspfinql8exr15+Mg17|I{6+of-f+ijb-Dt+ix-bnb14|DN318Ju66|EiG=3-fR#Qxiddbh10qC14+iIc16|I{6+jn1-n1+fd-doc+rk-wd15|DN317Ju66|BxG=1-z+z-jR<.lb1+b-c1+b-b8ezp12+hCib15|I{7+wl-lw+bcji-fg+j-ihd15|DN317Ju66|BxG=1-z+z-b&|E<-&k+bbfbd-ddf8fzo9+qqkbb15|I{8+wl-lw1+ckhg-dpddb14|DN318Ju66|BxG=3-bR|E^-Yo+eqqj1-gpsi8eg+c-hefehb+itgd18|I{8+jf-fj1+bh1jd-mhb16|DN317Ju66|BxEiG=2-bA|Fs-)k+qCzn-flwIze10b1cc+c-d+ec19|I{6+jf-fj5+b-e+dl-he16|DN318Ju66|Ei1G=3-kN,z+nJzk1-swR(j37|I{6+owf-pmfj4+b2-b16|DN318Ju66|Ei1G=3-bhrkD+vpo-hnAJ|EK-C36|I{7+jGo-bAoo24|DN318Ju66|Ei1G=5-ceee+je-bsvN|Ei37I{8+rye-ssj23|DN319Ju66|Ei2G=6-d+d3-k!|Ei34I{Ei1I{10+jf-fj23|DN320Ju66|Ei3G=11Ei33I{41DN321Ju66|Ei4G=9Ei33I{41DN322Ju66|Ei5G=3EiG=2Ei33I{41DN323Ju66|BxEi10G=Ei34I{40DN324Ju66|BxDN+S44|I{41DN324Ju66|BxDN1+S44|I{39DN325Ju66|BxDN2+S42|I{38DN327Ju66|Bx6Ei1Bx1Ei35I{38Bx327Ju"
    
    --=============================================================================================================================================================
    local heightMap                         = {}        ---@type table[]
    local terrainHasCliffs                  = {}        ---@type table[]
    local terrainCliffLevel                 = {}        ---@type table[]
    local terrainHasWater                   = {}        ---@type table[]
    local moveableLoc                       = nil       ---@type location
    local MINIMUM_Z                         = -2048     ---@type number
    local CLIFF_HEIGHT                      = 128       ---@type number
    local worldMinX
    local worldMinY
    local worldMaxX
    local worldMaxY
    local iMax
    local jMax
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!$&()[]=?:;,._#*~/{}<>^"
    local NUMBER_OF_CHARS = string.len(chars)
    ---@param x number
    ---@param y number
    ---@return number
    function GetLocZ(x, y)
        MoveLocation(moveableLoc, x, y)
        return GetLocationZ(moveableLoc)
    end
   
    GetTerrainZ = GetLocZ
    ---@param whichUnit unit
    ---@return number
    function GetUnitZ(whichUnit)
        return GetLocZ(GetUnitX(whichUnit), GetUnitY(whichUnit)) + GetUnitFlyHeight(whichUnit)
    end
    ---@param whichUnit unit
    ---@return number, number, number
    function GetUnitCoordinates(whichUnit)
        local x = GetUnitX(whichUnit)
        local y = GetUnitY(whichUnit)
        return x, y, GetLocZ(x, y) + GetUnitFlyHeight(whichUnit)
    end
    local function OverwriteHeightFunctions()
        ---@param x number
        ---@param y number
        ---@return number
        GetLocZ = function(x, y)
            local rx = (x - worldMinX)*0.0078125 + 1
            local ry = (y - worldMinY)*0.0078125 + 1
            local i = rx // 1
            local j = ry // 1
            rx = rx - i
            ry = ry - j
            if i < 1 then
                i = 1
                rx = 0
            elseif i > iMax then
                i = iMax
                rx = 1
            end
            if j < 1 then
                j = 1
                ry = 0
            elseif j > jMax then
                j = jMax
                ry = 1
            end
            local heightMapI = heightMap[i]
            local heightMapIplus1 = heightMap[i+1]
            return (1 - ry)*((1 - rx)*heightMapI[j] + rx*heightMapIplus1[j]) + ry*((1 - rx)*heightMapI[j+1] + rx*heightMapIplus1[j+1])
        end
        if STORE_CLIFF_DATA then
            ---@param x number
            ---@param y number
            ---@return number
            GetTerrainZ = function(x, y)
                local rx = (x - worldMinX)*0.0078125 + 1
                local ry = (y - worldMinY)*0.0078125 + 1
                local i = rx // 1
                local j = ry // 1
                rx = rx - i
                ry = ry - j
                if i < 1 then
                    i = 1
                    rx = 0
                elseif i > iMax then
                    i = iMax
                    rx = 1
                end
                if j < 1 then
                    j = 1
                    ry = 0
                elseif j > jMax then
                    j = jMax
                    ry = 1
                end
                if terrainHasCliffs[i][j] then
                    if rx < 0.5 then
                        if ry < 0.5 then
                            if STORE_WATER_DATA and terrainHasWater[i][j] then
                                return heightMap[i][j]
                            else
                                return (1 - rx - ry)*heightMap[i][j] + (rx*(heightMap[i+1][j] - CLIFF_HEIGHT*(terrainCliffLevel[i+1][j] - terrainCliffLevel[i][j])) + ry*(heightMap[i][j+1] - CLIFF_HEIGHT*(terrainCliffLevel[i][j+1] - terrainCliffLevel[i][j])))
                            end
                        elseif STORE_WATER_DATA and terrainHasWater[i][j] then
                            return heightMap[i][j+1]
                        elseif rx + ry > 1 then
                            return (rx + ry - 1)*(heightMap[i+1][j+1] - CLIFF_HEIGHT*(terrainCliffLevel[i+1][j+1] - terrainCliffLevel[i][j+1])) + ((1 - rx)*heightMap[i][j+1] + (1 - ry)*(heightMap[i+1][j] - CLIFF_HEIGHT*(terrainCliffLevel[i+1][j] - terrainCliffLevel[i][j+1])))
                        else
                            return (1 - rx - ry)*(heightMap[i][j] - CLIFF_HEIGHT*(terrainCliffLevel[i][j] - terrainCliffLevel[i][j+1])) + (rx*(heightMap[i+1][j] - CLIFF_HEIGHT*(terrainCliffLevel[i+1][j] - terrainCliffLevel[i][j+1])) + ry*heightMap[i][j+1])
                        end
                    elseif ry < 0.5 then
                        if STORE_WATER_DATA and terrainHasWater[i][j] then
                            return heightMap[i+1][j]
                        elseif rx + ry > 1 then
                            return (rx + ry - 1)*(heightMap[i+1][j+1] - CLIFF_HEIGHT*(terrainCliffLevel[i+1][j+1] - terrainCliffLevel[i+1][j])) + ((1 - rx)*(heightMap[i][j+1] - CLIFF_HEIGHT*(terrainCliffLevel[i][j+1] - terrainCliffLevel[i+1][j])) + (1 - ry)*heightMap[i+1][j])
                        else
                            return (1 - rx - ry)*(heightMap[i][j] - CLIFF_HEIGHT*(terrainCliffLevel[i][j] - terrainCliffLevel[i+1][j])) + (rx*heightMap[i+1][j] + ry*(heightMap[i][j+1] - CLIFF_HEIGHT*(terrainCliffLevel[i][j+1] - terrainCliffLevel[i+1][j])))
                        end
                    elseif STORE_WATER_DATA and terrainHasWater[i][j] then
                        return heightMap[i+1][j+1]
                    else
                        return (rx + ry - 1)*heightMap[i+1][j+1] + ((1 - rx)*(heightMap[i][j+1] - CLIFF_HEIGHT*(terrainCliffLevel[i][j+1] - terrainCliffLevel[i+1][j+1])) + (1 - ry)*(heightMap[i+1][j] - CLIFF_HEIGHT*(terrainCliffLevel[i+1][j] - terrainCliffLevel[i+1][j+1])))
                    end
                else
                    if rx + ry > 1 then --In top-right triangle
                        local heightMapIplus1 = heightMap[i+1]
                        return (rx + ry - 1)*heightMapIplus1[j+1] + ((1 - rx)*heightMap[i][j+1] + (1 - ry)*heightMapIplus1[j])
                    else
                        local heightMapI = heightMap[i]
                        return (1 - rx - ry)*heightMapI[j] + (rx*heightMap[i+1][j] + ry*heightMapI[j+1])
                    end
                end
            end
        else
            ---@param x number
            ---@param y number
            ---@return number
            GetTerrainZ = function(x, y)
                local rx = (x - worldMinX)*0.0078125 + 1
                local ry = (y - worldMinY)*0.0078125 + 1
                local i = rx // 1
                local j = ry // 1
                rx = rx - i
                ry = ry - j
                if i < 1 then
                    i = 1
                    rx = 0
                elseif i > iMax then
                    i = iMax
                    rx = 1
                end
                if j < 1 then
                    j = 1
                    ry = 0
                elseif j > jMax then
                    j = jMax
                    ry = 1
                end
                if rx + ry > 1 then --In top-right triangle
                    local heightMapIplus1 = heightMap[i+1]
                    return (rx + ry - 1)*heightMapIplus1[j+1] + ((1 - rx)*heightMap[i][j+1] + (1 - ry)*heightMapIplus1[j])
                else
                    local heightMapI = heightMap[i]
                    return (1 - rx - ry)*heightMapI[j] + (rx*heightMap[i+1][j] + ry*heightMapI[j+1])
                end
            end
        end
    end
    local function CreateHeightMap()
        local xMin = (worldMinX // 128)*128
        local yMin = (worldMinY // 128)*128
        local xMax = (worldMaxX // 128)*128 + 1
        local yMax = (worldMaxY // 128)*128 + 1
        local x = xMin
        local y
        local i = 1
        local j
        while x <= xMax do
            heightMap[i] = {}
            if STORE_CLIFF_DATA then
                terrainHasCliffs[i] = {}
                terrainCliffLevel[i] = {}
                if STORE_WATER_DATA then
                    terrainHasWater[i] = {}
                end
            end
            y = yMin
            j = 1
            while y <= yMax do
                heightMap[i][j] = GetLocZ(x,y)
                if VISUALIZE_HEIGHT_MAP then
                    BlzSetSpecialEffectZ(AddSpecialEffect("Doodads\\Cinematic\\GlowingRunes\\GlowingRunes0.mdl", x, y), heightMap[i][j] - 40)
                end
                if STORE_CLIFF_DATA then
                    local level1 = GetTerrainCliffLevel(x, y)
                    local level2 = GetTerrainCliffLevel(x, y + 128)
                    local level3 = GetTerrainCliffLevel(x + 128, y)
                    local level4 = GetTerrainCliffLevel(x + 128, y + 128)
                    if level1 ~= level2 or level1 ~= level3 or level1 ~= level4 then
                        terrainHasCliffs[i][j] = true
                    end
                    terrainCliffLevel[i][j] = level1
                    if STORE_WATER_DATA then
                        terrainHasWater[i][j] = not IsTerrainPathable(x, y, PATHING_TYPE_FLOATABILITY)
                        or not IsTerrainPathable(x, y + 128, PATHING_TYPE_FLOATABILITY)
                        or not IsTerrainPathable(x + 128, y, PATHING_TYPE_FLOATABILITY)
                        or not IsTerrainPathable(x + 128, y + 128, PATHING_TYPE_FLOATABILITY)
                    end
                end
                j = j + 1
                y = y + 128
            end
            i = i + 1
            x = x + 128
        end
        iMax = i - 2
        jMax = j - 2
    end
    local function ValidateHeightMap()
        local xMin = (worldMinX // 128)*128
        local yMin = (worldMinY // 128)*128
        local xMax = (worldMaxX // 128)*128 + 1
        local yMax = (worldMaxY // 128)*128 + 1
        local numOutdated = 0
        local x = xMin
        local y
        local i = 1
        local j
        while x <= xMax do
            y = yMin
            j = 1
            while y <= yMax do
                if heightMap[i][j] then
                    if VISUALIZE_HEIGHT_MAP then
                        BlzSetSpecialEffectZ(AddSpecialEffect("Doodads\\Cinematic\\GlowingRunes\\GlowingRunes0.mdl", x, y), heightMap[i][j] - 40)
                    end
                    if bj_isSinglePlayer and math.abs(heightMap[i][j] - GetLocZ(x, y)) > 1 then
                        numOutdated = numOutdated + 1
                    end
                else
                    print("Height Map nil at x = " .. x .. ", y = " .. y)
                end
                j = j + 1
                y = y + 128
            end
            i = i + 1
            x = x + 128
        end
       
        if numOutdated > 0 then
            print("|cffff0000Warning:|r Height Map is outdated at " .. numOutdated .. " locations...")
        end
    end
    local function ReadHeightMap()
        local charPos = 0
        local numRepetitions = 0
        local charValues = {}
   
        for i = 1, NUMBER_OF_CHARS do
            charValues[string.sub(chars, i, i)] = i - 1
        end
   
        local firstChar = nil
   
        local PLUS = 0
        local MINUS = 1
        local ABS = 2
        local segmentType = ABS
   
        for i = 1, #heightMap do
            for j = 1, #heightMap[i] do
                if numRepetitions > 0 then
                    heightMap[i][j] = heightMap[i][j-1]
                    numRepetitions = numRepetitions - 1
                else
                    local valueDetermined = false
                    while not valueDetermined do
                        charPos = charPos + 1
                        local char = string.sub(HeightMapCode, charPos, charPos)
                        if char == "+" then
                            segmentType = PLUS
                            charPos = charPos + 1
                            char = string.sub(HeightMapCode, charPos, charPos)
                        elseif char == "-" then
                            segmentType = MINUS
                            charPos = charPos + 1
                            char = string.sub(HeightMapCode, charPos, charPos)
                        elseif char == "|" then
                            segmentType = ABS
                            charPos = charPos + 1
                            char = string.sub(HeightMapCode, charPos, charPos)
                        end
                        if tonumber(char) then
                            local k = 0
                            while tonumber(string.sub(HeightMapCode, charPos + k + 1, charPos + k + 1)) do
                                k = k + 1
                            end
                            numRepetitions = tonumber(string.sub(HeightMapCode, charPos, charPos + k)) - 1
                            charPos = charPos + k
                            valueDetermined = true
                            heightMap[i][j] = heightMap[i][j-1]
                        else
                            if segmentType == PLUS then
                                heightMap[i][j] = heightMap[i][j-1] + charValues[char]
                                valueDetermined = true
                            elseif segmentType == MINUS then
                                heightMap[i][j] = heightMap[i][j-1] - charValues[char]
                                valueDetermined = true
                            elseif firstChar then
                                if charValues[firstChar] and charValues[char] then
                                    heightMap[i][j] = charValues[firstChar]*NUMBER_OF_CHARS + charValues[char] + MINIMUM_Z
                                else
                                    heightMap[i][j] = 0
                                end
                                firstChar = nil
                                valueDetermined = true
                            else
                                firstChar = char
                            end
                        end
                    end
                end
            end
        end
        HeightMapCode = nil
    end
    local function WriteHeightMap(subfolder)
        PreloadGenClear()
        PreloadGenStart()
   
        local numRepetitions = 0
        local firstChar
        local secondChar
        local stringLength = 0
        local lastValue = 0
   
        local PLUS = 0
        local MINUS = 1
        local ABS = 2
        local segmentType = ABS
        local preloadString = {'HeightMapCode = "'}
        for i = 1, #heightMap do
            for j = 1, #heightMap[i] do
                if j > 1 then
                    local diff = (heightMap[i][j] - lastValue)//1
                    if diff == 0 then
                        numRepetitions = numRepetitions + 1
                    else
                        if numRepetitions > 0 then
                            table.insert(preloadString, numRepetitions)
                        end
                        numRepetitions = 0
                        if diff > 0 and diff < NUMBER_OF_CHARS then
                            if segmentType ~= PLUS then
                                segmentType = PLUS
                                table.insert(preloadString, "+")
                            end
                        elseif diff < 0 and diff > -NUMBER_OF_CHARS then
                            if segmentType ~= MINUS then
                                segmentType = MINUS
                                table.insert(preloadString, "-")
                            end
                        else
                            if segmentType ~= ABS then
                                segmentType = ABS
                                table.insert(preloadString, "|")
                            end
                        end
   
                        if segmentType == ABS then
                            firstChar = (heightMap[i][j] - MINIMUM_Z) // NUMBER_OF_CHARS + 1
                            secondChar = heightMap[i][j]//1 - MINIMUM_Z - (heightMap[i][j]//1 - MINIMUM_Z)//NUMBER_OF_CHARS*NUMBER_OF_CHARS + 1
                            table.insert(preloadString, string.sub(chars, firstChar, firstChar) .. string.sub(chars, secondChar, secondChar))
                        elseif segmentType == PLUS then
                            firstChar = diff//1 + 1
                            table.insert(preloadString, string.sub(chars, firstChar, firstChar))
                        elseif segmentType == MINUS then
                            firstChar = -diff//1 + 1
                            table.insert(preloadString, string.sub(chars, firstChar, firstChar))
                        end
                    end
                else
                    if numRepetitions > 0 then
                        table.insert(preloadString, numRepetitions)
                    end
                    segmentType = ABS
                    table.insert(preloadString, "|")
                    numRepetitions = 0
                    firstChar = (heightMap[i][j] - MINIMUM_Z) // NUMBER_OF_CHARS + 1
                    secondChar = heightMap[i][j]//1 - MINIMUM_Z - (heightMap[i][j]//1 - MINIMUM_Z)//NUMBER_OF_CHARS*NUMBER_OF_CHARS + 1
                    table.insert(preloadString, string.sub(chars, firstChar, firstChar) .. string.sub(chars, secondChar, secondChar))
                end
   
                lastValue = heightMap[i][j]//1
   
                stringLength = stringLength + 1
                if stringLength == 100 then
                    Preload(table.concat(preloadString))
                    stringLength = 0
                    for k, __ in ipairs(preloadString) do
                        preloadString[k] = nil
                    end
                end
            end
        end
   
        if numRepetitions > 0 then
            table.insert(preloadString, numRepetitions)
        end
   
        table.insert(preloadString, '"')
        Preload(table.concat(preloadString))
   
        PreloadGenEnd(subfolder .. "\\heightMap.txt")
   
        print("Written Height Map to CustomMapData\\" .. subfolder .. "\\heightMap.txt")
    end
    local function InitHeightMap()
        local xMin = (worldMinX // 128)*128
        local yMin = (worldMinY // 128)*128
        local xMax = (worldMaxX // 128)*128 + 1
        local yMax = (worldMaxY // 128)*128 + 1
        local x = xMin
        local y
        local i = 1
        local j
        while x <= xMax do
            heightMap[i] = {}
            if STORE_CLIFF_DATA then
                terrainHasCliffs[i] = {}
                terrainCliffLevel[i] = {}
                if STORE_WATER_DATA then
                    terrainHasWater[i] = {}
                end
            end
            y = yMin
            j = 1
            while y <= yMax do
                heightMap[i][j] = 0
                if STORE_CLIFF_DATA then
                    local level1 = GetTerrainCliffLevel(x, y)
                    local level2 = GetTerrainCliffLevel(x, y + 128)
                    local level3 = GetTerrainCliffLevel(x + 128, y)
                    local level4 = GetTerrainCliffLevel(x + 128, y + 128)
                    if level1 ~= level2 or level1 ~= level3 or level1 ~= level4 then
                        terrainHasCliffs[i][j] = true
                    end
                    terrainCliffLevel[i][j] = level1
                    if STORE_WATER_DATA then
                        terrainHasWater[i][j] = not IsTerrainPathable(x, y, PATHING_TYPE_FLOATABILITY)
                        or not IsTerrainPathable(x, y + 128, PATHING_TYPE_FLOATABILITY)
                        or not IsTerrainPathable(x + 128, y, PATHING_TYPE_FLOATABILITY)
                        or not IsTerrainPathable(x + 128, y + 128, PATHING_TYPE_FLOATABILITY)
                    end
                end
                j = j + 1
                y = y + 128
            end
            i = i + 1
            x = x + 128
        end
        iMax = i - 2
        jMax = j - 2
    end
    OnInit.final("PrecomputedHeightMap", function()
        local worldBounds = GetWorldBounds()
        worldMinX = GetRectMinX(worldBounds)
        worldMinY = GetRectMinY(worldBounds)
        worldMaxX = GetRectMaxX(worldBounds)
        worldMaxY = GetRectMaxY(worldBounds)
        moveableLoc = Location(0, 0)    
        if HeightMapCode then
            InitHeightMap()
            ReadHeightMap()
            if bj_isSinglePlayer and VALIDATE_HEIGHT_MAP then
                ValidateHeightMap()
            end
            print("[HeightMap] Loaded from precomputed string. Grid " .. tostring(iMax+1) .. "x" .. tostring(jMax+1))
        else
            CreateHeightMap()
            if WRITE_HEIGHT_MAP then
                WriteHeightMap(SUBFOLDER)
            end
            print("[HeightMap] Generated at runtime. Grid " .. tostring(iMax+1) .. "x" .. tostring(jMax+1))
        end
        OverwriteHeightFunctions()
    end)
end
if Debug and Debug.endFile then Debug.endFile() end