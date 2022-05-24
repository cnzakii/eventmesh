package loadbalancer

import (
	"fmt"
	"github.com/apache/incubator-eventmesh/eventmesh-sdk-go/grpc/conf"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestIPHashRule_Choose(t *testing.T) {
	type fields struct {
		BaseRule BaseRule
	}
	type args struct {
		ip interface{}
	}
	fled := fields{
		BaseRule: func() BaseRule {
			lb, _ := NewLoadBalancer(conf.IPHash, []*StatusServer{
				{
					RealServer:      "127.0.0.1",
					ReadyForService: true,
					Host:            "127.0.0.1",
				},
				{
					RealServer:      "127.0.0.2",
					ReadyForService: true,
					Host:            "127.0.0.2",
				},
				{
					RealServer:      "127.0.0.3",
					ReadyForService: true,
					Host:            "127.0.0.3",
				},
			})
			return BaseRule{
				lb: lb,
			}
		}(),
	}
	tests := []struct {
		name    string
		fields  fields
		args    args
		want    interface{}
		wantErr assert.ErrorAssertionFunc
	}{
		{
			name:   "iphash with 1",
			fields: fled,
			args: args{
				ip: "127.1.1.1",
			},
			wantErr: func(t assert.TestingT, err error, i ...interface{}) bool {
				return false
			},
			want: "127.0.0.1",
		},
		{
			name:   "iphash with 2",
			fields: fled,
			args: args{
				ip: "168.1.1.2",
			},
			wantErr: func(t assert.TestingT, err error, i ...interface{}) bool {
				return true
			},
			want: "127.0.0.2",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			i := &IPHashRule{
				BaseRule: tt.fields.BaseRule,
			}
			got, err := i.Choose(tt.args.ip)
			if !tt.wantErr(t, err, fmt.Sprintf("Choose(%v)", tt.args.ip)) {
				return
			}
			assert.Equalf(t, tt.want, got.(*StatusServer).Host, "Choose(%v)", tt.args.ip)
		})
	}
}
