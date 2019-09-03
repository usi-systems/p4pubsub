import subprocess

class CamusCompiler:

    def __init__(self, spec_path, bin_path='/home/theo/p4pubsub/camus-compiler/camus.exe'):
        self.spec_path = spec_path
        self.bin_path = bin_path

    def compileRuntime(self, rules, out_prefix='/tmp/camus_runtime'):
        if isinstance(rules, list):
            rules_list = []
            for r in rules:
                assert isinstance(r, basestring)
                r = r.strip()
                if r[-1] != ';': r += ';'
                rules_list.append(r)
            rules_str = '\n'.join(rules_list)
        else:
            assert isinstance(rules, basestring)
            rules_str = rules

        p = subprocess.Popen([self.bin_path, '-rules', '-', '-rt-out', out_prefix, self.spec_path], stdin=subprocess.PIPE)
        p.communicate(input=rules_str)
        assert p.returncode == 0, "Compiler exited with error"

        entries_out = out_prefix + '_entries.json'
        mcast_out = out_prefix + '_mcast_groups.txt'

        return (entries_out, mcast_out)


if __name__ == '__main__':
    c = CamusCompiler('./spec.p4')

    with open('./rules.txt', 'r') as f:
        rules = f.readlines()

    print c.compileRuntime(rules)
