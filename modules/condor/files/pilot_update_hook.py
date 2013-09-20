#!/usr/bin/python

import os
import sys
import time
import errno
import classad
import htcondor

debuglog = False
chirp_verb = "set_job_attr_delayed"

if debuglog:
    debug_fp = open("/tmp/debug_pilot_hook", "w")
else:
    debug_fp = open("/dev/null", "w")
sys.stderr = debug_fp
sys.stdout = debug_fp

launch_time = time.time()

os.environ.setdefault("_CONDOR_CHIRP_CONFIG", ".chirp_config")

fd = os.popen("condor_config_val LIBEXEC")
libexec = fd.read().strip()
if not fd.close():
    if 'PATH' in os.environ:
        os.environ["PATH"] += ":" + libexec
    else:
        os.environ["PATH"] = libexec

def chirp(name, val, verb=None):
    global chirp_verb
    if verb == None: verb = chirp_verb
    print >> debug_fp, "Invoking condor_chirp %s %s %s" % (verb, name, val)
    pid = os.fork()
    # Use execv directly to avoid quoting issues in os.system and friends
    if not pid:
       try:
           try:
               os.dup2(debug_fp.fileno(), 1)
               os.dup2(debug_fp.fileno(), 2)
               os.execvpe("condor_chirp", ["condor_chirp", str(verb), str(name), str(val)], os.environ)
           except Exception, e:
               print >> debug_fp, str(e)
       finally:
           os._exit(1)

    pid, exit_status = os.waitpid(pid, 0)
    return exit_status

def chirp_one(verb, val):
    print >> debug_fp, "Invoking condor_chirp %s %s" % (verb, val)
    pid = os.fork()
    # Use execv directly to avoid quoting issues in os.system and friends
    if not pid:
       try:
           try:
               os.dup2(debug_fp.fileno(), 1)
               os.dup2(debug_fp.fileno(), 2)
               os.execvpe("condor_chirp", ["condor_chirp", str(verb), str(val)], os.environ)
           except Exception, e:
               print >> debug_fp, str(e)
       finally:
           os._exit(1)

    pid, exit_status = os.waitpid(pid, 0)
    return exit_status

def get_job_attr(name, delayed = False):
    verb = "get_job_attr"
    if delayed: verb = "get_job_attr_delayed"

    print >> debug_fp, "Invoking condor_chirp %s %s" % (verb, name)
    r, w = os.pipe()
    pid = os.fork()
    # Use execv directly to avoid quoting issues in os.system and friends
    if not pid:
       try:
           try:
               os.close(r)
               os.dup2(w, 1)
               os.dup2(debug_fp.fileno(), 2)
               os.execvpe("condor_chirp", ["condor_chirp", str(verb), str(name)], os.environ)
           except Exception, e:
               print >> debug_fp, str(e)
       finally:
           os._exit(1)
    os.close(w)

    pid, exit_status = os.waitpid(pid, 0)
    value = os.read(r, 16*1024)

    if not delayed and value == "(null)\n":
        return get_job_attr(name, True)

    return value, exit_status


def getStatus():
    base_dir = os.environ.get("_CONDOR_SCRATCH_DIR", os.getcwd())
    fd = open(os.path.join(base_dir, ".machine.ad"))
    machineAd = classad.parseOld(fd)
    return htcondor.Collector().query(htcondor.AdTypes.Startd, "Name =?= %s" % machineAd.lookup("Name").__str__())[0]


def getAd():
    ad = classad.ClassAd()
    ad["AD_FOUND"] = classad.ExprTree("false")
    ad["AD_FRESH"] = classad.ExprTree("false")
    fp = None
    try:
        fp = open(".pilot.ad")
        st = os.fstat(fp.fileno())
        ad["AD_FOUND"] = classad.ExprTree("true")
        if launch_time - st.st_mtime < 600:
            ad["AD_FRESH"] = classad.ExprTree("true")
        else:
            print "Pilot ad too old"
    except IOError, oe:
        if oe.errno == errno.ENOENT:
            print "No pilot ad available"
        else:
            raise
    if not fp: return ad
    pilot_ad = classad.parseOld(fp)
    for key in pilot_ad:
        if key not in ad:
            ad[key] = pilot_ad.lookup(key)
    return ad

def main():
    ad = getAd()
    global chirp_verb
    for attr in ad.keys():
        val = ad.lookup(attr)
        attr = "PILOT_" + attr
        if chirp(attr, val) and chirp_verb == "set_job_attr_delayed":
            chirp_verb = "set_job_attr"
            retval = chirp(attr, val)
            if retval:
                print "Chirp'ing failed (%d)!" % retval
                return retval

    if "LAST_EXP_JOB_END" in ad:
        chirp_one("set_expected_commit", str(ad["LAST_EXP_JOB_END"]))
    if "LAST_JOB_START" in ad:
        chirp_one("set_last_commit", str(ad["LAST_JOB_START"]))
        chirp("LastCommit", str(ad["LAST_JOB_START"]), "set_job_attr")

    preempt_expr, status = get_job_attr("LastPotentialPreemptionTime")
    preempt_expr = preempt_expr.strip()
    if not status and preempt_expr and preempt_expr != "(null)":
        try:
            preempt_expr = classad.ExprTree(preempt_expr).eval()
        except:
            preempt_expr = False
        if preempt_expr == classad.Value.Undefined:
            preempt_expr = False
    else:
        preempt_expr = False

    site_ad = classad.ClassAd()
    site_ad["VACATE_DESIRED"] = False

    starter_ad = getStatus()
    min_time = int(time.time() + 365*24*60*60)
    if starter_ad['Activity'] == "Retiring":
        min_time = min(min_time, starter_ad["MyCurrentTime"] + starter_ad["RetirementTimeRemaining"])
        site_ad["VACATE_DESIRED"] = True
    elif starter_ad.eval('Start') != True:
        min_time = min(min_time, time.time())
        site_ad["VACATE_DESIRED"] = True
    elif preempt_expr:
        site_ad["VACATE_DESIRED"] = True
    site_ad["PAYLOAD_DEADLINE"] = min_time
    site_ad["Cpus"] = starter_ad["Cpus"]

    base_dir = os.environ.get("_CONDOR_SCRATCH_DIR", os.getcwd())
    fd = open(os.path.join(base_dir, ".site.ad"), "w")
    fd.write(site_ad.printOld())

    return 0

if __name__ == "__main__":
    sys.exit(main())

