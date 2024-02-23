->the_kitchen
=== the_kitchen
- (top)
	<- drawers(-> top)
	<- cupboards(-> top)
	<- room_exits
	->DONE
= drawers (-> goback)
* drawers 1
* drawers 2
- ->goback

= cupboards(-> goback)
* cupboards 1
* cupboards 2
- ->goback

= room_exits
* exit1 ->END
* exit2 ->the_kitchen

