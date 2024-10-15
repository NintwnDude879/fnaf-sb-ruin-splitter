state ("fnaf9-Win64-Shipping"){}
startup {
    vars.CompletedSplits = new HashSet<string>();
    settings.CurrentDefaultParent = null;
    settings.Add("C1_End", true, "Chapter 1 End");
    settings.Add("C2_End", true, "Chapter 2 End");
    settings.Add("C3_End", true, "Chapter 3 End");
    settings.Add("C4_End", true, "Chapter 4 End");
    settings.Add("C5_End", true, "Chapter 5 End");
    settings.Add("C6_End", true, "Chapter 6 End");
    settings.Add("C7_End", true, "Chapter 7 End");
    settings.Add("C8_End", true, "Chapter 8 End");
    settings.Add("B_E", true, "Brazil Ending");
    settings.Add("S_E", true, "Scooper Ending");
    settings.Add("E_E", true, "Elevator Ending");
}

init {
    vars.justInMenu = false;
    vars.onLadder = false;
    refreshRate = 66.67;
    vars.cachedPos = new Vector3f(0, 0, 0);

    // Use sparsely, causes immense slowdown
    vars.printAllPointers = (Action)(() => {
        print("menu: "+current.menu.ToString());
        print("totalTime: "+current.totalTime.ToString());
        print("pos.X: "+current.pos.X.ToString());
        print("pos.Y: "+current.pos.Y.ToString());
        print("pos.Z: "+current.pos.Z.ToString());
        print("paused: "+current.paused.ToString());
    });

    vars.checkBox = (Func<string, Vector3f, Vector3f, bool>)((name, point1, point2) => {
        /* This first section is just to allow you to pick any two points directly opposite each other 
        on a cuboid and still allow for the rest of the code to work, it's really just for convenience's sake*/
        
        // Calculate which X/Y/Z is the lower of the two points, and set the upper/lower bound point along that axis accordingly
        Vector3f LB = new Vector3f(Math.Min(point1.X, point2.X), Math.Min(point1.Y, point2.Y), Math.Min(point1.Z, point2.Z));
        Vector3f UB = new Vector3f(Math.Max(point1.X, point2.X), Math.Max(point1.Y, point2.Y), Math.Max(point1.Z, point2.Z));

        // Actually calculate if you are in the bounds of the defined cuboid
        // Includes a bool called "check" to make sure you haven't already been in this box (i.e. on the previous frame)
		if (settings[name] && vars.CompletedSplits.Add(name) 
        && LB.X <= current.pos.X && current.pos.X <= UB.X 
        && LB.Y <= current.pos.Y && current.pos.Y <= UB.Y 
        && LB.Z <= current.pos.Z && current.pos.Z <= UB.Z){
			print(name);
			return true;
		}
		return false;
	});

    // ONLY USE WITH REAL WORLD BOX AS INPUT: input gets shifted DOWN to check another box in AR
    vars.checkRW_AR = (Func<string, Vector3f, Vector3f, bool>)((name, point1, point2) => {
        Vector3f lowerPoint1 = new Vector3f(point1.X, point1.Y, point1.Z-5000f);
        Vector3f lowerPoint2 = new Vector3f(point2.X, point2.Y, point2.Z-5000f);
        return (vars.checkBox(name, point1, point2) || vars.checkBox(name, lowerPoint1, lowerPoint2));
    });

    vars.GetStaticPointerFromSig = (Func<string, int, IntPtr>) ( (signature, instructionOffset) => {
    	var scanner = new SignatureScanner(game, modules.First().BaseAddress, (int)modules.First().ModuleMemorySize);
    	var pattern = new SigScanTarget(signature);
    	var location = scanner.Scan(pattern);
    	if (location == IntPtr.Zero) return IntPtr.Zero;
    	int offset = game.ReadValue<int>((IntPtr)location + instructionOffset);
    	return (IntPtr)location + offset + instructionOffset + 0x4;
    });

	vars.UWorld = vars.GetStaticPointerFromSig("E8 ???????? 48 8B 88 ??0?0000 48 89 0D ??????02", 15);
	vars.GEngine = vars.GetStaticPointerFromSig("48 8B 05 ???????? 48 8B D1 48 8B 88 F80A0000 48 85 C9 74 07 48 8B 01 48 FF 60 40", 3);

    vars.watchers = new MemoryWatcherList {
        // Stuff related to splitting
        new MemoryWatcher<Vector3f>(new DeepPointer(vars.GEngine, 0xD28, 0x38, 0x0, 0x30, 0x268, 0x298, 0x11C)) { Name = "pos" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<bool>(new DeepPointer(vars.UWorld, 0x138, 0x48, 0xA8, 0x758, 0x240)) { Name = "SRB_CanUse" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<bool>(new DeepPointer(vars.UWorld, 0x138, 0x48, 0xA8, 0x80, 0x3D4)) { Name = "ELE_WinState" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<bool>(new DeepPointer(vars.UWorld, 0x138, 0x48, 0xA8, 0x80, 0x460)) { Name = "ELE_inUse" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        // Stuff related to pausing the timer
        new MemoryWatcher<float>(new DeepPointer(vars.UWorld, 0x5A0)) { Name = "totalTime" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<bool>(new DeepPointer(vars.UWorld, 0x118, 0x1A8, 0x20, 0x100, 0xA0, 0x228)) { Name = "menu" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<bool>(new DeepPointer(vars.UWorld, 0x88, 0x0, 0x20, 0x118, 0x3A8)) { Name = "hasLoaded" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },


    };
}
update {
    // Some "old.name"s are commented out, as they aren't currently used in the code
    vars.watchers.UpdateAll(game);
    current.pos             = vars.watchers["pos"].Current;
    current.SRB_CanUse      = vars.watchers["SRB_CanUse"].Current;
    current.ELE_WinState    = vars.watchers["ELE_WinState"].Current;
    current.ELE_inUse       = vars.watchers["ELE_inUse"].Current;
    current.totalTime       = vars.watchers["totalTime"].Current;
    current.menu            = vars.watchers["menu"].Current;
    current.hasLoaded       = vars.watchers["hasLoaded"].Current;
    old.pos                 = vars.watchers["pos"].Old;
    old.SRB_CanUse          = vars.watchers["SRB_CanUse"].Old;
    //old.ELE_WinState      = vars.watchers["ELE_WinState"].Old;
    old.ELE_inUse           = vars.watchers["ELE_inUse"].Old;
    old.totalTime           = vars.watchers["totalTime"].Old;
    //old.menu              = vars.watchers["menu"].Old;
    old.hasLoaded           = vars.watchers["hasLoaded"].Old;
}   
start {
    // Cache the current position if the player just spawned in
    if ((old.pos.X == 0 && current.pos.X != 0) || (vars.cachedPos.X == 0 && current.pos.X != 0)){
        vars.cachedPos = new Vector3f(current.pos.X, current.pos.Y, current.pos.Z);
        print("Changed cachedPos to "+vars.cachedPos.ToString());
    }
    // Actually start the timer (works for individual chapters now as well :D)
    // Checks if the player has moved more than 1 unit in any direction 
    // (can't check if the player hasn't moved at all, sadly, since the starting cutscene displaces Cassie a bit)
    if (!current.menu && current.totalTime > 6
    && vars.cachedPos.DistanceXY(current.pos) > 2){
        print("Current: "+current.pos.ToString()+"\nCached: "+vars.cachedPos.ToString());
        return true;
    }
}
reset {
    if (current.pos.BitEquals(new Vector3f(-1270, 19228, 2075.63037109375f)))
        return true;
}
isLoading {
    if (current.menu) return true;
    if (!current.hasLoaded) return true;
    if (old.totalTime == current.totalTime) return true;

    // Getting off the loading screen is an animation with a set timer of roughly 4.1 seconds.
    // The code below caches the time when loading finishes, and waits until 4.1 more seconds have elapsed to resume the timer.
    if (current.hasLoaded && !old.hasLoaded){
        vars.cachedTime = current.totalTime;
    }

    if (current.hasLoaded && current.totalTime - vars.cachedTime < 4.05) return true;
    
    return false;
}
onStart {
    vars.CompletedSplits.Clear();
}
split {
    // May try to find a better way to do this in the future (such as finding a currentChapter variable or similar)
    // With current implementation, 2 position checks are needed for some chapters, as the player could be in either
    // AR or RW when entering the next chapter
    if (vars.checkBox("C1_End", new Vector3f(-25825, 43594, 1450), new Vector3f(-25418, 44000, 1750))){
        print("C1_End");
        return true;
    }
    if (vars.checkBox("C2_End", new Vector3f(-34750, 41250, 1730), new Vector3f(-34600, 41100, 1900))){
        print("C2_End");
        return true;
    }
    if (vars.checkBox("C3_End", new Vector3f(-46373, 46249, 1750), new Vector3f(-45729, 46536, 2000))){
        print("C3_End");
        return true;
    }
    if (vars.checkRW_AR("C4_End", new Vector3f(-49600, 72633, 2320), new Vector3f(-49400, 72958, 2700))){
        print("C4_End");
        return true;
    }
    if (vars.checkBox("C5_End", new Vector3f(-48815, 80876, 674), new Vector3f(-48653, 80717, 1014))){
        print("C5_End");
        return true;
    }
    if (vars.checkBox("C6_End", new Vector3f(-39090, 76754, 1398), new Vector3f(-38912, 76529, 1681))){
        print("C6_End");
        return true;
    }
    if (vars.checkRW_AR("C7_End", new Vector3f(-25499, 86232, 2080), new Vector3f(-25654, 86066, 2360))){
        print("C7_End");
        return true;
    }
    if (vars.checkRW_AR("C8_End", new Vector3f(-38080, 82827, 811), new Vector3f(-38175, 82633, 1042))){
        print("C8_End");
        return true;
    }
    if (vars.checkBox("B_E", new Vector3f(19123, 60899, -3054), new Vector3f(18874, 61153, -15000))){
        print("Brazil Ending");
        return true;
    }
    if (vars.checkBox("S_E", new Vector3f(16218, 55249, -2946), new Vector3f(17788, 57537, -2380)) && !current.SRB_CanUse && old.SRB_CanUse){
        print("Scooper Ending");
        return true;
    }
    if (vars.checkBox("E_E", new Vector3f(20772, 58473, -2906), new Vector3f(19863, 60427, -2251)) && !current.ELE_inUse && old.ELE_inUse && current.ELE_WinState){
        print("Elevator Ending");
        return true;
    }
}